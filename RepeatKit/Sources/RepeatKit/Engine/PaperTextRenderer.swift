import Foundation

/// Renders a generated paper as plain text.
///
/// This is the layout the PDF exporter mirrors, kept free of UIKit so the
/// structure can be checked without a device or simulator.
public struct PaperTextRenderer {

    public var showProvenance: Bool

    public init(showProvenance: Bool = true) {
        self.showProvenance = showProvenance
    }

    public func render(_ paper: GeneratedPaper) -> String {
        var lines: [String] = []
        let width = 66

        lines.append(center(paper.subjectCode.isEmpty
            ? paper.subject
            : "\(paper.subjectCode) — \(paper.subject)", width: width))
        lines.append(center(paper.patternName.uppercased(), width: width))
        lines.append("")

        let hours = Double(paper.durationMinutes) / 60
        let duration = hours == hours.rounded()
            ? "\(Int(hours)) hour\(hours == 1 ? "" : "s")"
            : String(format: "%.1f hours", hours)
        lines.append("Time: \(duration)".padding(toLength: width - 18, withPad: " ", startingAt: 0)
            + "Max Marks: \(paper.totalMarks)")
        lines.append(String(repeating: "-", count: width))

        for instruction in paper.generalInstructions {
            lines.append("Note: \(instruction)")
        }
        if !paper.generalInstructions.isEmpty { lines.append("") }

        for section in paper.sections {
            lines.append("")
            let header = "\(section.name.uppercased())  —  \(section.slots.count) × \(section.marksPerQuestion) = \(section.attemptableMarks) marks"
            lines.append(header)
            lines.append(section.instruction)
            lines.append("")

            for slot in section.slots {
                for (index, alternative) in slot.alternatives.enumerated() {
                    let label = alternative.letter.map { "\(slot.number). (\($0))" } ?? "\(slot.number)."
                    let prefix = index == 0 ? label : "     (\(alternative.letter ?? ""))"
                    lines.append(contentsOf: wrap(
                        prefix: prefix.padding(toLength: 9, withPad: " ", startingAt: 0),
                        text: alternative.text,
                        marks: alternative.marks,
                        width: width
                    ))
                    if showProvenance && alternative.occurrences > 1 {
                        let years = alternative.years.map(String.init).joined(separator: ", ")
                        lines.append("         ↳ asked \(alternative.occurrences)× (\(years))")
                    }
                    if index < slot.alternatives.count - 1 {
                        lines.append("         OR")
                    }
                }
                lines.append("")
            }
        }

        if !paper.warnings.isEmpty {
            lines.append(String(repeating: "-", count: width))
            lines.append("WARNINGS")
            for warning in paper.warnings { lines.append("  • \(warning)") }
        }

        return lines.joined(separator: "\n")
    }

    private func center(_ text: String, width: Int) -> String {
        let padding = max(0, (width - text.count) / 2)
        return String(repeating: " ", count: padding) + text
    }

    /// Wraps question text under a hanging indent, with the mark value flush right
    /// on the final line.
    private func wrap(prefix: String, text: String, marks: Int, width: Int) -> [String] {
        let indent = String(repeating: " ", count: prefix.count)
        let marksTag = "(\(marks))"
        let bodyWidth = width - prefix.count - marksTag.count - 2

        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if current.isEmpty {
                current = String(word)
            } else if current.count + word.count + 1 <= bodyWidth {
                current += " " + word
            } else {
                lines.append(current)
                current = String(word)
            }
        }
        if !current.isEmpty { lines.append(current) }
        if lines.isEmpty { lines = [""] }

        return lines.enumerated().map { index, line in
            let head = index == 0 ? prefix : indent
            if index == lines.count - 1 {
                let padded = (head + line).padding(
                    toLength: max((head + line).count, width - marksTag.count),
                    withPad: " ", startingAt: 0
                )
                return padded + marksTag
            }
            return head + line
        }
    }
}
