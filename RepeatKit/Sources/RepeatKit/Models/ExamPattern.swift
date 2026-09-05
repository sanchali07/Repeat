import Foundation

/// How a candidate is allowed to choose between questions in a section.
public enum ChoiceStyle: Codable, Hashable, Sendable {
    /// Every question is compulsory.
    case none
    /// Each slot prints two alternatives joined by OR — the Part B style.
    case internalChoice
    /// "Answer any `answer` of the `printed` questions below."
    case answerAny(answer: Int, printed: Int)

    /// How many questions must be printed to fill one answerable slot.
    var questionsPerSlot: Int {
        switch self {
        case .none: 1
        case .internalChoice: 2
        case .answerAny: 1
        }
    }
}

/// Which syllabus units a section draws from.
public enum UnitCoverage: Codable, Hashable, Sendable {
    /// Spread slots across all units as evenly as possible.
    case spreadAcrossAllUnits
    /// One slot per listed unit, in order — the usual "Q1 from Unit 1" rule.
    case oneSlotPerUnit(units: [Int])
    /// Draw only from these units, otherwise unconstrained.
    case restrictedTo(units: [Int])
    /// No constraint; purely highest-ranked questions.
    case unconstrained
}

/// One section of a paper, e.g. "Part A — 10 questions of 2 marks".
public struct PaperSection: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    /// Printed under the section heading, e.g. "Answer ALL questions".
    public var instruction: String
    public var marksPerQuestion: Int
    /// Number of answerable slots — not necessarily the number of printed questions.
    public var slotCount: Int
    public var choiceStyle: ChoiceStyle
    public var coverage: UnitCoverage

    public init(
        id: UUID = UUID(),
        name: String,
        instruction: String = "",
        marksPerQuestion: Int,
        slotCount: Int,
        choiceStyle: ChoiceStyle = .none,
        coverage: UnitCoverage = .spreadAcrossAllUnits
    ) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.marksPerQuestion = marksPerQuestion
        self.slotCount = slotCount
        self.choiceStyle = choiceStyle
        self.coverage = coverage
    }

    /// Marks a candidate can actually earn from this section.
    public var attemptableMarks: Int {
        switch choiceStyle {
        case .answerAny(let answer, _): answer * marksPerQuestion
        case .none, .internalChoice: slotCount * marksPerQuestion
        }
    }

    /// Total distinct questions that must be selected to print this section.
    public var questionsNeeded: Int {
        switch choiceStyle {
        case .none: slotCount
        case .internalChoice: slotCount * 2
        case .answerAny(_, let printed): printed
        }
    }
}

/// A full exam format. Editable end to end — this is what the pattern editor screen binds to.
public struct ExamPattern: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var durationMinutes: Int
    public var sections: [PaperSection]
    /// Printed at the top of the paper, above the sections.
    public var generalInstructions: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        durationMinutes: Int,
        sections: [PaperSection],
        generalInstructions: [String] = []
    ) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
        self.sections = sections
        self.generalInstructions = generalInstructions
    }

    public var totalMarks: Int {
        sections.reduce(0) { $0 + $1.attemptableMarks }
    }

    public var totalQuestionsNeeded: Int {
        sections.reduce(0) { $0 + $1.questionsNeeded }
    }
}

// MARK: - Presets

public extension ExamPattern {
    /// End Sem: 3 hours, 100 marks.
    /// Part A — 10 compulsory 2-markers spread across the syllabus.
    /// Part B — 5 slots of 16 marks, each printing two alternatives joined by OR,
    /// one slot per unit.
    static func endSemester(unitCount: Int = 5) -> ExamPattern {
        ExamPattern(
            name: "End Semester",
            durationMinutes: 180,
            sections: [
                PaperSection(
                    name: "Part A",
                    instruction: "Answer ALL questions.",
                    marksPerQuestion: 2,
                    slotCount: 10,
                    choiceStyle: .none,
                    coverage: .spreadAcrossAllUnits
                ),
                PaperSection(
                    name: "Part B",
                    instruction: "Answer ALL questions, choosing either (a) or (b).",
                    marksPerQuestion: 16,
                    slotCount: 5,
                    choiceStyle: .internalChoice,
                    coverage: .oneSlotPerUnit(units: Array(1...max(1, unitCount)))
                )
            ],
            generalInstructions: ["Answer Part A and Part B in the same answer book."]
        )
    }

    /// MST (Mid Semester Test): 90 minutes, 30 marks.
    /// Part A — five compulsory 2-markers (10 marks).
    /// Part B — five 5-mark questions printed, any four answered (20 marks).
    ///
    /// Provisional until the real paper is to hand; every field is editable in
    /// the pattern editor, so nothing here is baked in.
    ///
    /// - Parameter units: the syllabus units this test covers. MST-1 and MST-2
    ///   normally cover different halves of the syllabus.
    static func midSemesterTest(number: Int, units: [Int], durationMinutes: Int = 90) -> ExamPattern {
        ExamPattern(
            name: "MST-\(number)",
            durationMinutes: durationMinutes,
            sections: [
                PaperSection(
                    name: "Part A",
                    instruction: "Answer ALL questions.",
                    marksPerQuestion: 2,
                    slotCount: 5,
                    choiceStyle: .none,
                    coverage: .restrictedTo(units: units)
                ),
                PaperSection(
                    name: "Part B",
                    instruction: "Answer any FOUR of the following five questions.",
                    marksPerQuestion: 5,
                    slotCount: 5,
                    choiceStyle: .answerAny(answer: 4, printed: 5),
                    coverage: .restrictedTo(units: units)
                )
            ]
        )
    }

    /// MST-1 — first half of the syllabus.
    static func mst1(units: [Int] = [1, 2]) -> ExamPattern {
        midSemesterTest(number: 1, units: units)
    }

    /// MST-2 — second half of the syllabus.
    static func mst2(units: [Int] = [3, 4]) -> ExamPattern {
        midSemesterTest(number: 2, units: units)
    }
}
