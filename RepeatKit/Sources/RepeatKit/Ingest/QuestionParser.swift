import Foundation

/// Turns the raw text of one question paper into individual questions.
///
/// Written for OCR output from photographed papers, so it assumes the text is
/// noisy: broken lines, stray characters, missing punctuation, and mangled
/// numbering. It prefers to under-extract rather than invent — anything it is
/// unsure of is flagged for the student to confirm rather than silently kept.
public struct QuestionParser {

    public struct Result: Sendable {
        public var questions: [Question]
        /// Lines that looked like questions but failed a check, kept so the
        /// review screen can show what was skipped and why.
        public var skipped: [String]
        public var detectedYear: Int?
        public var detectedSource: SourceKind?
    }

    public init() {}

    // MARK: - Patterns

    /// "1.", "1)", "Q1.", "11. (a)", "Q.13"
    ///
    /// The sub-part letter MUST carry a closing bracket or dot. Leaving those
    /// optional made the "D" of "Define" match as sub-part (d), which turned
    /// "2. Define subnetting." into question 2(d) reading "efine subnetting."
    private static let questionStart = try! NSRegularExpression(
        pattern: #"^\s*(?:Q\.?\s*)?(\d{1,2})\s*[\.\)\:]\s*(?:(?:\(([a-dA-D])\)|([a-dA-D])[\)\.])\s+)?(.*)$"#
    )
    /// A sub-part continuing the previous number: "(a) ...", "b) ..."
    private static let subPartStart = try! NSRegularExpression(
        pattern: #"^\s*(?:\(([a-dA-D])\)|([a-dA-D])[\)\.])\s+(.{6,})$"#
    )
    /// The alternative separator printed between (a) and (b). It belongs to
    /// neither question, so it must end the one in progress rather than be
    /// appended to it.
    private static let choiceSeparator = try! NSRegularExpression(
        pattern: #"^\s*[\(\[]?\s*(?:or)\s*[\)\]]?\s*[\.\,]?\s*$"#,
        options: [.caseInsensitive]
    )
    /// Trailing mark annotation: "(16)", "[2]", "(2 Marks)", "- 16 M"
    private static let trailingMarks = try! NSRegularExpression(
        pattern: #"[\(\[\-\s](\d{1,2})\s*(?:m|mk|mks|mark|marks)?\s*[\)\]]?\s*$"#,
        options: [.caseInsensitive]
    )
    private static let sectionHeader = try! NSRegularExpression(
        pattern: #"^\s*(?:PART|SECTION)\s*[-–—:]?\s*([A-D])\b"#, options: [.caseInsensitive]
    )
    private static let yearPattern = try! NSRegularExpression(pattern: #"\b(19|20)(\d{2})\b"#)

    /// Boilerplate that appears on every paper and is never a question.
    private static let boilerplate = [
        "reg. no", "reg no", "register number", "roll no", "answer all",
        "answer any", "max. marks", "maximum marks", "time:", "duration",
        "university", "college", "institute", "semester", "b.e.", "b.tech",
        "degree examination", "instructions", "page ", "this paper", "all questions carry"
    ]

    // MARK: - Parsing

    public func parse(
        text: String,
        documentName: String,
        source: SourceKind? = nil,
        year: Int? = nil
    ) -> Result {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let detectedYear = year ?? Self.detectYear(in: lines, documentName: documentName)
        let detectedSource = source ?? Self.detectSource(in: lines, documentName: documentName)

        var questions: [Question] = []
        var skipped: [String] = []

        var currentNumber: String?
        var currentBody: [String] = []
        var currentMarks: Int?
        var lastMajorNumber: Int?

        func flush() {
            defer { currentBody = []; currentMarks = nil; currentNumber = nil }
            let body = currentBody.joined(separator: " ")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !body.isEmpty else { return }

            guard Self.looksLikeAQuestion(body) else {
                skipped.append(body)
                return
            }
            questions.append(
                Question(
                    text: TextNormalizer.presentable(body),
                    marks: currentMarks,
                    year: detectedYear,
                    source: detectedSource ?? .other,
                    number: currentNumber,
                    documentName: documentName
                )
            )
        }

        for line in lines {
            if Self.matches(Self.sectionHeader, line) { continue }
            if Self.matches(Self.choiceSeparator, line) { flush(); continue }
            if Self.isBoilerplate(line) { flush(); continue }

            if let match = Self.capture(Self.questionStart, line), let major = Int(match[1] ?? "") {
                flush()
                lastMajorNumber = major
                // Group 2 is the "(a)" form, group 3 the "a)" form, group 4 the body.
                let sub = (match[2] ?? match[3])?.lowercased()
                currentNumber = sub.map { "\(major)(\($0))" } ?? "\(major)"
                let (body, marks) = Self.stripMarks(match[4] ?? "")
                currentBody = body.isEmpty ? [] : [body]
                currentMarks = marks
            } else if let match = Self.capture(Self.subPartStart, line), let major = lastMajorNumber {
                flush()
                let sub = (match[1] ?? match[2] ?? "").lowercased()
                currentNumber = "\(major)(\(sub))"
                let (body, marks) = Self.stripMarks(match[3] ?? "")
                currentBody = body.isEmpty ? [] : [body]
                currentMarks = marks
            } else if currentNumber != nil {
                // Continuation of the question in progress.
                let (body, marks) = Self.stripMarks(line)
                if let marks { currentMarks = currentMarks ?? marks }
                if !body.isEmpty { currentBody.append(body) }
            }
        }
        flush()

        return Result(
            questions: questions,
            skipped: skipped,
            detectedYear: detectedYear,
            detectedSource: detectedSource
        )
    }

    // MARK: - Helpers

    /// Rejects fragments that are too short, have no letters, or are almost all
    /// digits — the usual OCR debris from marks columns and page furniture.
    static func looksLikeAQuestion(_ text: String) -> Bool {
        guard text.count >= 12 else { return false }
        let letters = text.filter(\.isLetter).count
        guard letters >= 8 else { return false }
        guard Double(letters) / Double(text.count) > 0.5 else { return false }
        // Two words is the real floor: 1-mark questions are routinely
        // "Define subnetting." or "Expand SMTP." A 3-word minimum silently
        // dropped every one of them.
        guard text.split(separator: " ").count >= 2 else { return false }
        return !isBoilerplate(text)
    }

    static func isBoilerplate(_ line: String) -> Bool {
        let lower = line.lowercased()
        return boilerplate.contains { lower.contains($0) }
    }

    /// Splits a trailing mark annotation off the end of a line.
    static func stripMarks(_ line: String) -> (String, Int?) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let match = capture(trailingMarks, trimmed),
              let value = Int(match[1] ?? ""),
              (1...100).contains(value)
        else { return (trimmed, nil) }

        let range = Range(match.range, in: trimmed)!
        let body = String(trimmed[trimmed.startIndex..<range.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        // A line that is only a mark value carries no question text.
        return (body, value)
    }

    static func detectYear(in lines: [String], documentName: String) -> Int? {
        let haystack = ([documentName] + lines.prefix(12)).joined(separator: " ")
        guard let match = capture(yearPattern, haystack),
              let year = Int((match[1] ?? "") + (match[2] ?? ""))
        else { return nil }
        let thisYear = Calendar.current.component(.year, from: .now)
        return (1990...thisYear + 1).contains(year) ? year : nil
    }

    static func detectSource(in lines: [String], documentName: String) -> SourceKind? {
        let haystack = ([documentName] + lines.prefix(12)).joined(separator: " ").lowercased()
        if haystack.contains("assignment") || haystack.contains("tutorial") { return .assignment }
        if haystack.contains("mst") || haystack.contains("mid sem") || haystack.contains("midsem")
            || haystack.contains("sessional") || haystack.contains("internal") { return .midSem }
        if haystack.contains("end sem") || haystack.contains("endsem")
            || haystack.contains("semester examination") { return .endSem }
        return nil
    }

    // MARK: - Regex plumbing

    struct Capture {
        let range: NSRange
        private let groups: [String?]
        init(_ match: NSTextCheckingResult, in text: String) {
            range = match.range
            groups = (0..<match.numberOfRanges).map { index in
                guard let r = Range(match.range(at: index), in: text) else { return nil }
                return String(text[r])
            }
        }
        subscript(index: Int) -> String? { index < groups.count ? groups[index] : nil }
    }

    static func capture(_ regex: NSRegularExpression, _ text: String) -> Capture? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return Capture(match, in: text)
    }

    static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        capture(regex, text) != nil
    }
}
