import Foundation

/// Builds a question paper from ranked clusters, honouring a pattern's section
/// counts, mark values, choice rules and unit coverage.
public struct PaperGenerator {

    /// Preference for questions historically worth the section's mark value.
    /// A 16-mark slot should not be filled with a question only ever asked as a 2-marker.
    public var marksMatchBonus: Double
    /// How far a question's usual mark value may stretch to fill a slot.
    /// 4.0 lets a 5-marker fill a 16-mark slot but keeps 2-markers out of it.
    public var marksTolerance: Double
    public var currentYear: Int

    public init(
        marksMatchBonus: Double = 1.6,
        marksTolerance: Double = 4.0,
        currentYear: Int = Calendar.current.component(.year, from: .now)
    ) {
        self.marksMatchBonus = marksMatchBonus
        self.marksTolerance = marksTolerance
        self.currentYear = currentYear
    }

    public func generate(
        from clusters: [QuestionCluster],
        pattern: ExamPattern,
        syllabus: Syllabus
    ) -> GeneratedPaper {
        var used = Set<UUID>()
        var warnings: [String] = []
        var sections: [GeneratedSection] = []
        var slotNumber = 1

        for section in pattern.sections {
            let plan = unitPlan(for: section, syllabus: syllabus)
            var slots: [PaperSlot] = []

            // `.answerAny` prints more questions than the candidate answers,
            // so the printed count comes from the choice rule, not the slot count.
            let printedCount: Int
            if case .answerAny(_, let printed) = section.choiceStyle {
                printedCount = printed
            } else {
                printedCount = section.slotCount
            }

            for slotIndex in 0..<printedCount {
                let preferredUnit = plan.isEmpty ? nil : plan[slotIndex % plan.count]
                let needed = section.choiceStyle.questionsPerSlot
                var alternatives: [PaperAlternative] = []

                for alternativeIndex in 0..<needed {
                    let picked = pick(
                        from: clusters,
                        marks: section.marksPerQuestion,
                        preferredUnit: preferredUnit,
                        allowedUnits: allowedUnits(for: section.coverage),
                        unitsAreHard: isHardRestriction(section.coverage),
                        excluding: used,
                        warnings: &warnings
                    )

                    if let picked {
                        used.insert(picked.id)
                        alternatives.append(
                            PaperAlternative(
                                letter: needed > 1 ? (alternativeIndex == 0 ? "a" : "b") : nil,
                                text: picked.canonicalText,
                                marks: section.marksPerQuestion,
                                unitNumber: picked.unitNumber,
                                occurrences: picked.occurrences,
                                years: picked.years
                            )
                        )
                    } else {
                        let unitLabel = preferredUnit.map { "Unit \($0)" } ?? "the syllabus"
                        warnings.append(
                            "\(section.name) slot \(slotIndex + 1): no unused \(section.marksPerQuestion)-mark question left for \(unitLabel). Add more papers, or widen the marks tolerance."
                        )
                        alternatives.append(
                            PaperAlternative(
                                letter: needed > 1 ? (alternativeIndex == 0 ? "a" : "b") : nil,
                                text: "[No unused past question available — add more papers, or lower the marks match.]",
                                marks: section.marksPerQuestion,
                                unitNumber: preferredUnit,
                                isPlaceholder: true
                            )
                        )
                    }
                }

                slots.append(PaperSlot(number: slotNumber, alternatives: alternatives))
                slotNumber += 1
            }

            sections.append(
                GeneratedSection(
                    name: section.name,
                    instruction: resolvedInstruction(for: section),
                    marksPerQuestion: section.marksPerQuestion,
                    attemptableMarks: section.attemptableMarks,
                    slots: slots
                )
            )
        }

        return GeneratedPaper(
            subject: syllabus.subject,
            subjectCode: syllabus.code,
            patternName: pattern.name,
            durationMinutes: pattern.durationMinutes,
            totalMarks: pattern.totalMarks,
            generalInstructions: pattern.generalInstructions,
            sections: sections,
            warnings: warnings
        )
    }

    // MARK: - Selection

    /// Highest-scoring unused cluster, preferring the target unit but never
    /// violating a hard unit restriction, and never placing a question at a mark
    /// value it could not plausibly carry.
    private func pick(
        from clusters: [QuestionCluster],
        marks: Int,
        preferredUnit: Int?,
        allowedUnits: Set<Int>?,
        unitsAreHard: Bool,
        excluding used: Set<UUID>,
        warnings: inout [String]
    ) -> QuestionCluster? {
        var available = clusters.filter { !used.contains($0.id) }

        // A section restricted to specific units must never spill outside them —
        // an MST on Units 1-2 asking a Unit 5 question is simply wrong.
        if unitsAreHard, let allowedUnits {
            available = available.filter { $0.unitNumber.map(allowedUnits.contains) ?? false }
        }

        // A question only ever asked as a 2-marker cannot carry 16 marks, and vice
        // versa. Better to leave the slot flagged than to print a nonsensical fit.
        available = available.filter { isPlausible($0, at: marks) }
        guard !available.isEmpty else { return nil }

        // Tier 1: exactly the unit we want.
        if let preferredUnit {
            let inUnit = available.filter { $0.unitNumber == preferredUnit }
            if let best = highestScoring(inUnit, matching: marks) { return best }
        }
        // Tier 2: any unit this section may draw from.
        if let allowedUnits {
            let inScope = available.filter { $0.unitNumber.map(allowedUnits.contains) ?? false }
            if let best = highestScoring(inScope, matching: marks) { return best }
        }
        // Tier 3: anything left, including questions we could not map to a unit.
        return highestScoring(available, matching: marks)
    }

    /// Whether a question has ever plausibly been worth this many marks.
    /// Unmapped-marks questions are allowed through; we simply do not know.
    private func isPlausible(_ cluster: QuestionCluster, at marks: Int) -> Bool {
        if cluster.marksHistogram[marks] != nil { return true }
        guard let typical = cluster.typicalMarks else { return true }
        let ratio = Double(max(typical, marks)) / Double(max(1, min(typical, marks)))
        return ratio <= marksTolerance
    }

    private func highestScoring(_ clusters: [QuestionCluster], matching marks: Int) -> QuestionCluster? {
        clusters.max { lhs, rhs in
            rankingScore(lhs, marks: marks) < rankingScore(rhs, marks: marks)
        }
    }

    /// Repeat frequency and recency, boosted when the question has actually been
    /// asked at this mark value before.
    private func rankingScore(_ cluster: QuestionCluster, marks: Int) -> Double {
        var score = cluster.score(currentYear: currentYear)
        if cluster.marksHistogram[marks] != nil {
            score *= marksMatchBonus
        } else if let typical = cluster.typicalMarks {
            // Penalise in proportion to how far off the usual weight is — a
            // 2-marker stretched to 16 is a worse fit than a 10 stretched to 16.
            let distance = Double(abs(typical - marks)) / Double(max(marks, 1))
            score *= max(0.35, 1.0 - 0.6 * distance)
        }
        return score
    }

    // MARK: - Coverage

    /// The unit to aim for on each successive slot of a section.
    private func unitPlan(for section: PaperSection, syllabus: Syllabus) -> [Int] {
        let allUnits = syllabus.units.map(\.number).sorted()
        switch section.coverage {
        case .unconstrained:
            return []
        case .spreadAcrossAllUnits:
            return allUnits
        case .oneSlotPerUnit(let units):
            return units.isEmpty ? allUnits : units
        case .restrictedTo(let units):
            return units.isEmpty ? allUnits : units
        }
    }

    private func allowedUnits(for coverage: UnitCoverage) -> Set<Int>? {
        switch coverage {
        case .unconstrained, .spreadAcrossAllUnits:
            return nil
        case .oneSlotPerUnit(let units), .restrictedTo(let units):
            return units.isEmpty ? nil : Set(units)
        }
    }

    /// `.restrictedTo` is a hard boundary; `.oneSlotPerUnit` is only a preference
    /// for which unit leads each slot.
    private func isHardRestriction(_ coverage: UnitCoverage) -> Bool {
        if case .restrictedTo = coverage { return true }
        return false
    }

    private func resolvedInstruction(for section: PaperSection) -> String {
        if !section.instruction.isEmpty { return section.instruction }
        switch section.choiceStyle {
        case .none:
            return "Answer ALL questions."
        case .internalChoice:
            return "Answer ALL questions, choosing either (a) or (b)."
        case .answerAny(let answer, let printed):
            return "Answer any \(answer) of the following \(printed) questions."
        }
    }
}
