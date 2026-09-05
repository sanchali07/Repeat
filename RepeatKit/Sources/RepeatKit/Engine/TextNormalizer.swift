import Foundation

/// Reduces a question to the content words that identify it, so that
/// "Explain the working of DNS." and "Describe how DNS works" collapse together.
enum TextNormalizer {

    /// Pure grammar — carries no topic meaning.
    private static let functionWords: Set<String> = [
        "the", "a", "an", "of", "in", "on", "for", "with", "and", "to", "is", "are",
        "be", "by", "from", "its", "it", "that", "which", "any", "all", "as", "at",
        "or", "into", "their", "them", "there", "this", "these", "those", "you",
        "your", "we", "he", "she", "they", "do", "does", "can", "will", "would",
        "shall", "should", "may", "have", "has", "had", "was", "were", "been"
    ]

    /// Exam scaffolding that appears in front of almost every question and so
    /// tells us nothing about which question it is.
    private static let genericVerbs: Set<String> = [
        "explain", "describe", "discuss", "write", "define", "give",
        "illustrate", "elaborate", "mention", "briefly", "brief", "detail",
        "details", "short", "note", "notes", "about", "what", "how", "why",
        "when", "where", "following", "also", "using", "use", "consider",
        "suitable", "example", "examples", "neat", "diagram", "sketch",
        "question", "answer", "marks", "mark"
    ]

    /// Verbs that genuinely change what is being asked are kept: compare,
    /// differentiate, derive, prove, calculate, design, implement, analyze.
    ///
    /// "state" is deliberately NOT in the list above. It reads as an exam verb in
    /// "State the purpose of ICMP", but it is a technical noun in "link state
    /// routing" — stripping it collapsed that topic to [link, routing] and let
    /// "distance vector routing" win the specificity tiebreak, merging two
    /// different questions. IDF already discounts it wherever it is just a verb.

    /// True for grammar and exam scaffolding that identifies no topic.
    static func isNoise(_ word: String) -> Bool {
        functionWords.contains(word) || genericVerbs.contains(word)
    }

    static func tokens(_ text: String) -> [String] {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 1 }
            .filter { !functionWords.contains($0) && !genericVerbs.contains($0) }
            .map(singularize)
    }

    /// Conservative plural stripping — enough to match "protocols"/"protocol"
    /// without mangling "address" or "analysis".
    private static func singularize(_ word: String) -> String {
        guard word.count > 3 else { return word }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("ss") || word.hasSuffix("us") || word.hasSuffix("is") { return word }
        if word.hasSuffix("es") && word.count > 4 { return String(word.dropLast(2)) }
        if word.hasSuffix("s") { return String(word.dropLast()) }
        return word
    }

    /// Character trigrams of the joined tokens, to catch near-misses that
    /// word overlap alone would miss (typos, OCR damage, hyphenation).
    static func trigrams(_ tokens: [String]) -> Set<String> {
        let joined = tokens.joined(separator: " ")
        guard joined.count >= 3 else { return [] }
        let chars = Array(joined)
        return Set((0...(chars.count - 3)).map { String(chars[$0..<($0 + 3)]) })
    }

    static func jaccard<T: Hashable>(_ a: Set<T>, _ b: Set<T>) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 1 }
        let union = a.union(b).count
        guard union > 0 else { return 1 }
        return Double(a.intersection(b).count) / Double(union)
    }

    /// 0...1 similarity between two raw question strings.
    static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let lhsTokens = tokens(lhs)
        let rhsTokens = tokens(rhs)
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return 0 }

        let wordScore = jaccard(Set(lhsTokens), Set(rhsTokens))
        let charScore = jaccard(trigrams(lhsTokens), trigrams(rhsTokens))
        // Word overlap is the stronger signal; trigrams rescue OCR noise.
        return 0.65 * wordScore + 0.35 * charScore
    }

    /// Tidies a question for printing: collapses whitespace, strips a trailing
    /// mark annotation like "(16)" or "[2 Marks]", ensures terminal punctuation.
    static func presentable(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(
            of: "[\\(\\[]\\s*\\d+\\s*(marks?|m)?\\s*[\\)\\]]\\s*$",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        ).trimmingCharacters(in: .whitespaces)
        if let last = cleaned.last, !".?:".contains(last) { cleaned += "." }
        return cleaned
    }
}
