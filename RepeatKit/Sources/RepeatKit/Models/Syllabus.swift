import Foundation

/// A single unit of a subject's syllabus, e.g. "Unit III — Transport Layer".
public struct SyllabusUnit: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// 1-based unit number as printed in the syllabus.
    public var number: Int
    public var title: String
    /// The topic lines listed under this unit. Used to map questions onto units.
    public var topics: [String]

    public init(id: UUID = UUID(), number: Int, title: String, topics: [String] = []) {
        self.id = id
        self.number = number
        self.title = title
        self.topics = topics
    }

    /// Every phrase that can identify this unit, for keyword matching.
    var matchableTerms: [String] { [title] + topics }
}

public struct Syllabus: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var subject: String
    public var code: String
    public var units: [SyllabusUnit]

    public init(id: UUID = UUID(), subject: String, code: String = "", units: [SyllabusUnit] = []) {
        self.id = id
        self.subject = subject
        self.code = code
        self.units = units
    }

    public func unit(numbered number: Int) -> SyllabusUnit? {
        units.first { $0.number == number }
    }
}
