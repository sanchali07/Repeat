import Foundation
import CoreGraphics
import CoreText
import PDFKit
import RepeatKit

// Builds a PDF whose pages are IMAGES of an exam paper — no text layer at all —
// so the ingestor is forced down the same OCR path as a photographed paper.

let paperLines: [(String, CGFloat, Bool)] = [
    ("ANNA UNIVERSITY", 15, true),
    ("B.E. DEGREE EXAMINATION, NOVEMBER 2023", 12, true),
    ("Sixth Semester", 11, true),
    ("CS3591 - COMPUTER NETWORKS", 13, true),
    ("", 10, false),
    ("Time: Three hours                    Maximum: 100 marks", 11, false),
    ("", 10, false),
    ("PART A - (10 x 2 = 20 marks)", 12, true),
    ("Answer ALL questions.", 11, false),
    ("", 8, false),
    ("1. What is meant by network topology?                    (2)", 11, false),
    ("2. Define subnetting.                                     (2)", 11, false),
    ("3. State the purpose of ICMP.                             (2)", 11, false),
    ("4. Differentiate between TCP and UDP.                     (2)", 11, false),
    ("5. What is web caching?                                   (2)", 11, false),
    ("", 8, false),
    ("PART B - (5 x 16 = 80 marks)", 12, true),
    ("", 8, false),
    ("11. (a) Explain the working of DNS with a neat diagram.  (16)", 11, false),
    ("Or", 11, false),
    ("(b) Explain HTTP request and response message format.    (16)", 11, false),
    ("", 8, false),
    ("12. (a) Explain the TCP three way handshake used for", 11, false),
    ("connection establishment.                                (16)", 11, false),
    ("Or", 11, false),
    ("(b) Explain congestion control mechanisms in TCP.        (16)", 11, false),
]

func renderPaperImage() -> CGImage {
    let width = 1240, height = 1754   // A4 at 150 dpi
    let context = CGContext(data: nil, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    var y = CGFloat(height) - 110
    for (text, size, bold) in paperLines {
        defer { y -= size * 2.6 }
        guard !text.isEmpty else { continue }
        let font = CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, size * 2.0, nil)
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: CGColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1)
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        let x: CGFloat = bold ? (CGFloat(width) - bounds.width) / 2 : 90
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }
    return context.makeImage()!
}

let scratch = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("scanned-2023.pdf")
let image = renderPaperImage()
let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
var mediaBox = pageRect
let consumer = CGDataConsumer(url: scratch as CFURL)!
let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
pdf.beginPDFPage(nil)
pdf.draw(image, in: pageRect)
pdf.endPDFPage()
pdf.closePDF()

print("Synthesized image-only PDF at \(scratch.path)\n")

// --- Ingest it exactly as the app will ---

let ingestor = DocumentIngestor()
let pages = try ingestor.ingest(pdfAt: scratch)

for page in pages {
    print("Page \(page.index + 1): \(page.wasOCR ? "OCR" : "embedded text"), "
          + "confidence \(String(format: "%.2f", page.confidence))")
}

let parser = QuestionParser()
let result = parser.parse(
    text: pages.map(\.text).joined(separator: "\n"),
    documentName: "scanned-2023.pdf"
)

print("\nDetected year: \(result.detectedYear.map(String.init) ?? "none")")
print("Detected source: \(result.detectedSource?.label ?? "none")")
print("Extracted \(result.questions.count) questions, skipped \(result.skipped.count) fragments.\n")

for question in result.questions {
    let number = question.number ?? "?"
    let marks = question.marks.map { "\($0)m" } ?? "—"
    print("  [\(number)] (\(marks)) \(question.text)")
}

if !result.skipped.isEmpty {
    print("\nSkipped (shown to the student for review, never silently dropped):")
    for fragment in result.skipped { print("  · \(fragment.prefix(70))") }
}

print("\n--- RAW OCR TEXT ---")
for (i, line) in pages.map(\.text).joined(separator: "\n").components(separatedBy: .newlines).enumerated() {
    print(String(format: "%2d |%@|", i, line))
}
