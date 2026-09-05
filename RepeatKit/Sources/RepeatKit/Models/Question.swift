import Foundation

/// Where a question came from. Assignments count as a signal but are weighted
/// lower than real papers when ranking.
public enum SourceKind: String, Codable, CaseIterable, Sendable {
    case endSem
    case midSem
    case assignment
    case other

    /// How much a sighting from this source counts toward a cluster's score.
    var credibility: Double {
        switch self {
        case .endSem: 1.0
        case .midSem: 0.9
        case .assignment: 0.5
        case .other: 0.7
        }
    }

    public var label: String {
        switch self {
        case .endSem: "End Sem"
        case .midSem: "Mid Sem"
        case .assignment: "Assignment"
        case .other: "Other"
        }
    }
}

/// One question as it literally appeared in one document.
public struct Question: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var text: String
    /// Marks printed against the question, when the paper stated them.
    public var marks: Int?
    /// Calendar year of the paper, e.g. 2023.
    public var year: Int?
    public var source: SourceKind
    /// Question number as printed, e.g. "5(a)".
    public var number: String?
    /// Filename or title of the document this came from.
    public var documentName: String
    /// Syllabus unit number this was mapped to, once mapping has run.
    public var unitNumber: Int?
    /// The specific syllabus topic this question is about, e.g. "link state routing".
    /// Two questions on different listed topics are never merged, however similar
    /// their wording — this is what keeps "distance vector routing" apart from
    /// "link state routing".
    public var topicKey: String?

    public init(
        id: UUID = UUID(),
        text: String,
        marks: Int? = nil,
        year: Int? = nil,
        source: SourceKind = .endSem,
        number: String? = nil,
        documentName: String = "",
        unitNumber: Int? = nil,
        topicKey: String? = nil
    ) {
        self.id = id
        self.text = text
        self.marks = marks
        self.year = year
        self.source = source
        self.number = number
        self.documentName = documentName
        self.unitNumber = unitNumber
        self.topicKey = topicKey
    }
}

/// A group of questions that are the same question, allowing for rewording.
/// This is the unit the app actually ranks and picks from.
public struct QuestionCluster: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// The phrasing shown in the UI and printed into generated papers.
    public var canonicalText: String
    public var variants: [Question]
    public var unitNumber: Int?
    public var topicKey: String?

    public init(id: UUID = UUID(), canonicalText: String, variants: [Question], unitNumber: Int? = nil, topicKey: String? = nil) {
        self.id = id
        self.canonicalText = canonicalText
        self.variants = variants
        self.unitNumber = unitNumber
        self.topicKey = topicKey
    }

    /// How many times this question has been seen at all.
    public var occurrences: Int { variants.count }

    /// Distinct years it appeared in, newest first.
    public var years: [Int] {
        Array(Set(variants.compactMap(\.year))).sorted(by: >)
    }

    /// Marks it has carried, and how often — the same question can be a 2-marker
    /// one year and a 16-marker the next.
    public var marksHistogram: [Int: Int] {
        variants.compactMap(\.marks).reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    /// The mark value this question most often carries.
    public var typicalMarks: Int? {
        marksHistogram.max { a, b in
            a.value == b.value ? a.key < b.key : a.value < b.value
        }?.key
    }

    public var mostRecentYear: Int? { years.first }

    /// Ranking score: repeats matter most, recent sightings matter more than old
    /// ones, and assignments count for less than real papers.
    public func score(currentYear: Int) -> Double {
        variants.reduce(0.0) { total, variant in
            let age = variant.year.map { Double(max(0, currentYear - $0)) } ?? 6.0
            let recency = exp(-age / 5.0)
            return total + variant.source.credibility * (0.4 + 0.6 * recency)
        }
    }
}
