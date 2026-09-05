import Foundation

/// One printed alternative within a slot.
public struct PaperAlternative: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// "a" / "b" for internal choice, nil when the slot has no alternatives.
    public var letter: String?
    public var text: String
    public var marks: Int
    public var unitNumber: Int?
    /// How many times this question has appeared historically — shown as a
    /// confidence badge next to the question.
    public var occurrences: Int
    public var years: [Int]
    /// Set when the generator could not find a real past question for this slot.
    public var isPlaceholder: Bool

    public init(
        id: UUID = UUID(),
        letter: String? = nil,
        text: String,
        marks: Int,
        unitNumber: Int? = nil,
        occurrences: Int = 0,
        years: [Int] = [],
        isPlaceholder: Bool = false
    ) {
        self.id = id
        self.letter = letter
        self.text = text
        self.marks = marks
        self.unitNumber = unitNumber
        self.occurrences = occurrences
        self.years = years
        self.isPlaceholder = isPlaceholder
    }
}

/// One answerable slot, e.g. "11. (a) ... OR (b) ...".
public struct PaperSlot: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var number: Int
    public var alternatives: [PaperAlternative]

    public init(id: UUID = UUID(), number: Int, alternatives: [PaperAlternative]) {
        self.id = id
        self.number = number
        self.alternatives = alternatives
    }
}

public struct GeneratedSection: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var instruction: String
    public var marksPerQuestion: Int
    public var attemptableMarks: Int
    public var slots: [PaperSlot]

    public init(
        id: UUID = UUID(),
        name: String,
        instruction: String,
        marksPerQuestion: Int,
        attemptableMarks: Int,
        slots: [PaperSlot]
    ) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.marksPerQuestion = marksPerQuestion
        self.attemptableMarks = attemptableMarks
        self.slots = slots
    }
}

/// A complete generated question paper, ready to render to PDF.
public struct GeneratedPaper: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var subject: String
    public var subjectCode: String
    public var patternName: String
    public var durationMinutes: Int
    public var totalMarks: Int
    public var generalInstructions: [String]
    public var sections: [GeneratedSection]
    public var generatedAt: Date
    /// Problems the generator hit, surfaced in the UI rather than silently ignored —
    /// e.g. "Unit 4 had only 1 question at 16 marks; 2 slots were filled from other units."
    public var warnings: [String]

    public init(
        id: UUID = UUID(),
        subject: String,
        subjectCode: String,
        patternName: String,
        durationMinutes: Int,
        totalMarks: Int,
        generalInstructions: [String],
        sections: [GeneratedSection],
        generatedAt: Date = .now,
        warnings: [String] = []
    ) {
        self.id = id
        self.subject = subject
        self.subjectCode = subjectCode
        self.patternName = patternName
        self.durationMinutes = durationMinutes
        self.totalMarks = totalMarks
        self.generalInstructions = generalInstructions
        self.sections = sections
        self.generatedAt = generatedAt
        self.warnings = warnings
    }
}
