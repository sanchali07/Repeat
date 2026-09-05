import Foundation

/// Groups questions that are really the same question asked again, including
/// when the examiner reworded it.
public struct QuestionClusterer {

    /// Cosine similarity above which two questions are treated as the same.
    /// Measured against real papers: reworded repeats land around 0.5-0.8,
    /// while related-but-different questions on the same topic sit below 0.4.
    /// Similarity required to merge two questions that share no syllabus topic.
    /// Deliberately strict: with no topic agreement, wording is all we have.
    public var threshold: Double
    /// Similarity required to merge two questions already known to be about the
    /// same syllabus topic. Lower, because the topic match is itself strong
    /// evidence — it only has to separate genuinely different questions on one topic.
    public var withinTopicThreshold: Double
    /// How far two questions' mark values may differ and still be considered the
    /// same question. A 2-mark "Define subnetting." and a 16-mark "Explain
    /// subnetting in detail." are about one topic but they are not one question:
    /// one wants a sentence, the other wants four pages. Without this guard,
    /// topic anchoring happily merges them and the short question inherits the
    /// long one's mark value.
    public var marksTolerance: Double
    public var indexConfig: SemanticIndex.Config

    public init(
        threshold: Double = 0.45,
        withinTopicThreshold: Double = 0.20,
        marksTolerance: Double = 3.0,
        indexConfig: SemanticIndex.Config = .init()
    ) {
        self.threshold = threshold
        self.withinTopicThreshold = withinTopicThreshold
        self.marksTolerance = marksTolerance
        self.indexConfig = indexConfig
    }

    public func cluster(_ questions: [Question]) -> [QuestionCluster] {
        // IDF is learned from this specific subject's papers, so the terms that
        // matter are the ones that are rare *in this subject*.
        let index = SemanticIndex(corpus: questions.map(\.text), config: indexConfig)
        let vectors = questions.map { index.vector(for: $0.text) }

        var buckets: [[Int]] = []          // indices into `questions`
        var centroids: [[String: Double]] = []
        var bucketTopics: [String?] = []
        var bucketMarks: [Int?] = []

        for questionIndex in questions.indices {
            let vector = vectors[questionIndex]
            guard !vector.isEmpty else { continue }
            let topic = questions[questionIndex].topicKey

            var bestBucket: Int?
            var bestScore = 0.0
            for bucketIndex in buckets.indices {
                let bucketTopic = bucketTopics[bucketIndex]
                // Two questions the syllabus says are about different topics are
                // different questions, however alike they read.
                if let topic, let bucketTopic, topic != bucketTopic { continue }
                // Same topic, wildly different weight: a different question.
                if !marksAreCompatible(questions[questionIndex].marks, bucketMarks[bucketIndex]) { continue }
                let sameTopic = topic != nil && topic == bucketTopic
                let required = sameTopic ? withinTopicThreshold : threshold

                let score = index.cosine(vector, centroids[bucketIndex])
                if score >= required && score > bestScore {
                    bestScore = score
                    bestBucket = bucketIndex
                }
            }

            if let bestBucket {
                buckets[bestBucket].append(questionIndex)
                centroids[bestBucket] = index.centroid(of: buckets[bestBucket].map { vectors[$0] })
                if bucketTopics[bestBucket] == nil { bucketTopics[bestBucket] = topic }
                if bucketMarks[bestBucket] == nil { bucketMarks[bestBucket] = questions[questionIndex].marks }
            } else {
                buckets.append([questionIndex])
                centroids.append(vector)
                bucketTopics.append(topic)
                bucketMarks.append(questions[questionIndex].marks)
            }
        }

        return buckets.map { indices in
            let variants = indices.map { questions[$0] }
            return QuestionCluster(
                canonicalText: canonicalText(for: variants),
                variants: variants.sorted { ($0.year ?? 0) > ($1.year ?? 0) },
                unitNumber: dominantUnit(in: variants),
                topicKey: variants.compactMap(\.topicKey).first
            )
        }
    }

    /// Unknown marks never block a merge — we simply do not know enough to object.
    private func marksAreCompatible(_ lhs: Int?, _ rhs: Int?) -> Bool {
        guard let lhs, let rhs, lhs > 0, rhs > 0 else { return true }
        let ratio = Double(max(lhs, rhs)) / Double(min(lhs, rhs))
        return ratio <= marksTolerance
    }

    /// How confidently two questions are the same — surfaced in the UI so the
    /// student can see why two questions were merged, and split them if wrong.
    public func similarityReport(_ questions: [Question]) -> SemanticIndex {
        SemanticIndex(corpus: questions.map(\.text), config: indexConfig)
    }

    /// Prints the most recent full-length phrasing — recent papers reflect how the
    /// examiner words it now, and longer variants retain qualifiers that shorter
    /// OCR-clipped ones lost.
    private func canonicalText(for variants: [Question]) -> String {
        let best = variants
            .sorted {
                let leftYear = $0.year ?? 0, rightYear = $1.year ?? 0
                if leftYear != rightYear { return leftYear > rightYear }
                return $0.text.count > $1.text.count
            }
            .first
        return TextNormalizer.presentable(best?.text ?? "")
    }

    private func dominantUnit(in variants: [Question]) -> Int? {
        let counts = variants.compactMap(\.unitNumber).reduce(into: [Int: Int]()) {
            $0[$1, default: 0] += 1
        }
        return counts.max { a, b in
            a.value == b.value ? a.key > b.key : a.value < b.value
        }?.key
    }
}
