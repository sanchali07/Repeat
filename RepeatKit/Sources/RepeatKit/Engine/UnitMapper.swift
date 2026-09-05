import Foundation

/// Assigns each question to the syllabus unit it belongs to, by overlap between
/// the question's content words and the unit's topic list.
///
/// This is the deterministic pass. Anything it leaves `nil` is a candidate for
/// an LLM pass later — those are the questions whose wording shares no vocabulary
/// with the syllabus.
public struct UnitMapper {

    /// Minimum overlap before we commit to a unit rather than leaving it unmapped.
    public var minimumScore: Double

    public init(minimumScore: Double = 0.08) {
        self.minimumScore = minimumScore
    }

    public func map(_ questions: [Question], to syllabus: Syllabus) -> [Question] {
        // Pre-tokenize each unit's topics once.
        let unitVocabularies: [(number: Int, terms: Set<String>)] = syllabus.units.map { unit in
            let terms = unit.matchableTerms.flatMap { TextNormalizer.tokens($0) }
            return (unit.number, Set(terms))
        }

        return questions.map { question in
            var question = question
            // Respect a unit the user or the source document already established.
            guard question.unitNumber == nil else { return question }
            question.unitNumber = bestUnit(for: question.text, in: unitVocabularies)
            return question
        }
    }

    private func bestUnit(
        for text: String,
        in vocabularies: [(number: Int, terms: Set<String>)]
    ) -> Int? {
        let questionTokens = Set(TextNormalizer.tokens(text))
        guard !questionTokens.isEmpty else { return nil }

        var bestNumber: Int?
        var bestScore = minimumScore

        for vocabulary in vocabularies {
            let overlap = questionTokens.intersection(vocabulary.terms).count
            guard overlap > 0 else { continue }
            // Normalize by the question's own length so long questions don't
            // automatically beat short ones, and so a unit with a huge topic
            // list doesn't swallow everything.
            let score = Double(overlap) / Double(questionTokens.count)
            if score > bestScore {
                bestScore = score
                bestNumber = vocabulary.number
            }
        }
        return bestNumber
    }
}
