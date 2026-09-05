import Foundation
import NaturalLanguage

/// Similarity model for short technical exam questions.
///
/// Apple's `NLEmbedding` sentence vectors were measured against this exact corpus
/// and ranked two unrelated questions as more similar than two identical ones —
/// they are trained on general prose and collapse on terse technical text. So this
/// uses IDF-weighted term vectors instead: a term that appears in few questions
/// ("DNS", "hamming") dominates the comparison, while a term in almost every
/// question ("explain", "detail") contributes nothing.
///
/// Every step is deterministic arithmetic over the user's own papers. There is no
/// generative model here and therefore nothing that can invent a match.
public struct SemanticIndex: Sendable {

    /// Inverse document frequency per term, learned from the corpus.
    private let idf: [String: Double]
    /// Fallback weight for a term never seen during indexing.
    private let unseenIDF: Double
    private let config: Config

    public struct Config: Sendable {
        /// Weight of two-word phrases relative to single words. Phrases like
        /// "three way handshake" identify a question far better than its words do.
        public var bigramWeight: Double
        /// Extra weight for acronyms (DNS, TCP, HTTP, OSI) — in a technical paper
        /// these are the single strongest identifier of what is being asked.
        public var acronymBoost: Double

        public init(bigramWeight: Double = 1.5, acronymBoost: Double = 1.8) {
            self.bigramWeight = bigramWeight
            self.acronymBoost = acronymBoost
        }
    }

    public init(corpus: [String], config: Config = Config()) {
        self.config = config
        let documents = corpus.map { Self.terms(in: $0, config: config).keys }

        var documentFrequency: [String: Int] = [:]
        for terms in documents {
            for term in Set(terms) { documentFrequency[term, default: 0] += 1 }
        }

        let count = Double(max(1, corpus.count))
        self.idf = documentFrequency.mapValues { frequency in
            log((count + 1) / (Double(frequency) + 1)) + 1
        }
        self.unseenIDF = log(count + 1) + 1
    }

    // MARK: - Similarity

    /// Cosine similarity in 0...1 between two questions.
    public func similarity(_ lhs: String, _ rhs: String) -> Double {
        cosine(vector(for: lhs), vector(for: rhs))
    }

    /// IDF-weighted, L2-normalized term vector for one question.
    public func vector(for text: String) -> [String: Double] {
        let counts = Self.terms(in: text, config: config)
        guard !counts.isEmpty else { return [:] }

        var vector: [String: Double] = [:]
        for (term, weight) in counts {
            vector[term] = weight * (idf[term] ?? unseenIDF)
        }
        return normalized(vector)
    }

    public func normalized(_ vector: [String: Double]) -> [String: Double] {
        let magnitude = sqrt(vector.values.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.mapValues { $0 / magnitude }
    }

    public func cosine(_ lhs: [String: Double], _ rhs: [String: Double]) -> Double {
        // Iterate the smaller vector; the vectors are already unit length.
        let (small, large) = lhs.count <= rhs.count ? (lhs, rhs) : (rhs, lhs)
        var total = 0.0
        for (term, weight) in small {
            if let other = large[term] { total += weight * other }
        }
        return max(0, min(1, total))
    }

    /// Mean of several unit vectors, renormalized — the centroid of a cluster.
    public func centroid(of vectors: [[String: Double]]) -> [String: Double] {
        guard !vectors.isEmpty else { return [:] }
        var sum: [String: Double] = [:]
        for vector in vectors {
            for (term, weight) in vector { sum[term, default: 0] += weight }
        }
        return normalized(sum.mapValues { $0 / Double(vectors.count) })
    }

    // MARK: - Term extraction

    /// Content words plus adjacent-word bigrams, with raw weights.
    static func terms(in text: String, config: Config) -> [String: Double] {
        let words = contentWords(in: text)
        guard !words.isEmpty else { return [:] }

        var terms: [String: Double] = [:]
        for word in words {
            terms[word.lemma, default: 0] += word.isAcronym ? config.acronymBoost : 1.0
        }
        for index in 0..<max(0, words.count - 1) {
            let bigram = "\(words[index].lemma)_\(words[index + 1].lemma)"
            terms[bigram, default: 0] += config.bigramWeight
        }
        return terms
    }

    struct ContentWord {
        let lemma: String
        let isAcronym: Bool
    }

    /// Tokenizes, drops exam scaffolding, and lemmatizes via `NLTagger` so
    /// "protocols"/"protocol" and "resolves"/"resolve" unify properly.
    static func contentWords(in text: String) -> [ContentWord] {
        let cleaned = text.replacingOccurrences(
            of: "[^A-Za-z0-9 ]", with: " ", options: .regularExpression
        )

        // Record which raw tokens were written as acronyms before case is lost.
        var acronyms = Set<String>()
        for token in cleaned.split(separator: " ") where token.count >= 2 {
            if token.allSatisfy({ $0.isUppercase || $0.isNumber }) && token.contains(where: \.isLetter) {
                acronyms.insert(token.lowercased())
            }
        }

        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = cleaned
        // Short questions defeat automatic language detection, which makes every
        // lemma come back nil — "subnetting" would stay raw in one question and
        // lemmatize to "subnet" in another, so they would never match. Force it.
        tagger.setLanguage(.english, range: cleaned.startIndex..<cleaned.endIndex)
        var words: [ContentWord] = []

        tagger.enumerateTags(
            in: cleaned.startIndex..<cleaned.endIndex,
            unit: .word,
            scheme: .lemma,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, range in
            let raw = String(cleaned[range]).lowercased()
            guard raw.count > 1 else { return true }
            guard !TextNormalizer.isNoise(raw) else { return true }
            let lemma = tag?.rawValue.lowercased() ?? raw
            words.append(ContentWord(lemma: lemma.isEmpty ? raw : lemma,
                                     isAcronym: acronyms.contains(raw)))
            return true
        }
        return words
    }
}
