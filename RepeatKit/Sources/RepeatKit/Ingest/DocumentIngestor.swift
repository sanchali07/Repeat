import Foundation
import Vision
import PDFKit
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

/// Reads text out of question papers, whether they are real text PDFs or — as is
/// usual — PDFs containing photographs of the printed paper.
///
/// Everything runs on-device through Vision. Nothing is uploaded, nothing costs
/// money, and because OCR only transcribes what is on the page it cannot invent
/// a question that was never asked.
public struct DocumentIngestor {

    public struct Page: Sendable {
        public let index: Int
        public let text: String
        /// True when the text came from OCR rather than an embedded text layer.
        public let wasOCR: Bool
        /// Vision's mean confidence for this page, 0...1. Low values are surfaced
        /// in the review screen so the student knows which pages to check.
        public let confidence: Double
    }

    public enum IngestError: Error, LocalizedError {
        case unreadableDocument
        case pageRenderFailed(Int)

        public var errorDescription: String? {
            switch self {
            case .unreadableDocument: "That file could not be opened as a PDF or image."
            case .pageRenderFailed(let index): "Page \(index + 1) could not be rendered for text recognition."
            }
        }
    }

    /// Pixels per point when rasterizing a PDF page for OCR. Photographed papers
    /// are often low resolution, and Vision does markedly better with upscaling.
    public var renderScale: CGFloat
    /// Below this, a page's embedded text layer is treated as absent and we OCR instead.
    public var minimumEmbeddedCharacters: Int

    public init(renderScale: CGFloat = 3.0, minimumEmbeddedCharacters: Int = 120) {
        self.renderScale = renderScale
        self.minimumEmbeddedCharacters = minimumEmbeddedCharacters
    }

    // MARK: - Entry points

    public func ingest(pdfAt url: URL) throws -> [Page] {
        guard let document = PDFDocument(url: url) else { throw IngestError.unreadableDocument }
        return try ingest(document: document)
    }

    public func ingest(document: PDFDocument) throws -> [Page] {
        try (0..<document.pageCount).map { index in
            guard let page = document.page(at: index) else {
                throw IngestError.pageRenderFailed(index)
            }
            // A real text PDF needs no OCR — use its text layer, which is exact.
            let embedded = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if embedded.count >= minimumEmbeddedCharacters {
                return Page(index: index, text: embedded, wasOCR: false, confidence: 1.0)
            }
            let image = try render(page: page, index: index)
            let (text, confidence) = try recognizeText(in: image)
            return Page(index: index, text: text, wasOCR: true, confidence: confidence)
        }
    }

    public func ingest(imageAt url: URL) throws -> Page {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw IngestError.unreadableDocument }
        let (text, confidence) = try recognizeText(in: image)
        return Page(index: 0, text: text, wasOCR: true, confidence: confidence)
    }

    // MARK: - Rendering

    private func render(page: PDFPage, index: Int) throws -> CGImage {
        let bounds = page.bounds(for: .mediaBox)
        let width = Int(bounds.width * renderScale)
        let height = Int(bounds.height * renderScale)
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else { throw IngestError.pageRenderFailed(index) }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: renderScale, y: renderScale)
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
        page.draw(with: .mediaBox, to: context)

        guard let image = context.makeImage() else { throw IngestError.pageRenderFailed(index) }
        return image
    }

    // MARK: - Recognition

    /// Reads text top-to-bottom, preserving line breaks, which the question parser
    /// relies on to find where each numbered question starts.
    func recognizeText(in image: CGImage) throws -> (String, Double) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else { return ("", 0) }

        // Vision returns observations in reading order but with normalized
        // coordinates whose origin is bottom-left; sort top-to-bottom, then
        // left-to-right, so multi-column papers still read sensibly.
        let sorted = observations.sorted { lhs, rhs in
            let verticalGap = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
            if verticalGap > 0.01 { return lhs.boundingBox.midY > rhs.boundingBox.midY }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        var lines: [String] = []
        var confidenceTotal = 0.0
        var confidenceCount = 0

        for observation in sorted {
            guard let candidate = observation.topCandidates(1).first else { continue }
            lines.append(candidate.string)
            confidenceTotal += Double(candidate.confidence)
            confidenceCount += 1
        }

        let confidence = confidenceCount > 0 ? confidenceTotal / Double(confidenceCount) : 0
        return (lines.joined(separator: "\n"), confidence)
    }
}
