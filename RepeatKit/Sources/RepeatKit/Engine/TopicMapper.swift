import Foundation

/// Assigns each question to the syllabus topic it is actually about, and to the
/// unit that topic belongs to.
///
/// The syllabus is the concept vocabulary. It is the only thing that reliably
/// separates two questions whose wording overlaps heavily but which are asking
/// about different listed topics — "distance vector routing" and "link state
/// routing" share most of their words but are separate entries in the syllabus,
/// so questions on them must never be merged.
public struct TopicMapper {

    /// Fraction of a topic phrase that must appear in the question before we
    /// accept that the question is about that topic.
    public var minimumContainment: Double

    public init(minimumContainment: Double = 0.6) {
        self.minimumContainment = minimumContainment
    }

    private struct Topic {
        let key: String
        let unitNumber: Int
        let terms: [String]
        /// Longer, more specific phrases win ties against broader ones.
        var specificity: Int { terms.count }
    }

    public func map(_ questions: [Question], to syllabus: Syllabus) -> [Question] {
        let topics: [Topic] = syllabus.units.flatMap { unit in
            unit.matchableTerms.compactMap { phrase in
                let terms = SemanticIndex.contentWords(in: phrase).map(\.lemma)
                guard !terms.isEmpty else { return nil }
                return Topic(key: phrase.lowercased(), unitNumber: unit.number, terms: terms)
            }
        }

        return questions.map { question in
            var question = question
            let words = SemanticIndex.contentWords(in: question.text).map(\.lemma)
            guard !words.isEmpty else { return question }

            if question.topicKey == nil, let match = bestTopic(for: words, among: topics) {
                question.topicKey = match.key
                if question.unitNumber == nil { question.unitNumber = match.unitNumber }
            }
            // Fall back to whole-unit matching for questions that name no listed topic.
            if question.unitNumber == nil {
                question.unitNumber = bestUnit(for: words, in: syllabus)
            }
            return question
        }
    }

    /// The most specific topic whose phrase is substantially contained in the
    /// question. Ties break toward whichever topic appears earliest — a question
    /// that mentions two topics is normally about the one it leads with.
    private func bestTopic(for words: [String], among topics: [Topic]) -> Topic? {
        let wordSet = Set(words)
        var best: (topic: Topic, position: Int)?

        for topic in topics {
            let present = topic.terms.filter(wordSet.contains)
            let containment = Double(present.count) / Double(topic.terms.count)
            guard containment >= minimumContainment else { continue }
            // Single-word topics must match exactly, or "TCP" would claim every
            // question that happens to mention TCP in passing.
            guard topic.terms.count > 1 || containment == 1.0 else { continue }

            let position = topic.terms.compactMap { words.firstIndex(of: $0) }.min() ?? words.count

            guard let current = best else { best = (topic, position); continue }
            if topic.specificity != current.topic.specificity {
                if topic.specificity > current.topic.specificity { best = (topic, position) }
            } else if position < current.position {
                best = (topic, position)
            }
        }
        return best?.topic
    }

    private func bestUnit(for words: [String], in syllabus: Syllabus) -> Int? {
        let wordSet = Set(words)
        var bestNumber: Int?
        var bestScore = 0.08

        for unit in syllabus.units {
            let vocabulary = Set(unit.matchableTerms.flatMap { SemanticIndex.contentWords(in: $0).map(\.lemma) })
            let overlap = wordSet.intersection(vocabulary).count
            guard overlap > 0 else { continue }
            let score = Double(overlap) / Double(wordSet.count)
            if score > bestScore {
                bestScore = score
                bestNumber = unit.number
            }
        }
        return bestNumber
    }
}
