import SwiftUI

/// The signature element: a vertical bar whose colour encodes how often a
/// question has been asked. It lets the eye rank the list before reading it.
struct HeatRail: View {
    let occurrences: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Theme.heat(occurrences))
            .frame(width: 3)
    }
}

/// "asked 6×" in the matching heat colour, or "asked once" for a one-off.
struct HeatLabel: View {
    let occurrences: Int

    var body: some View {
        Text(occurrences == 1 ? "asked once" : "asked \(occurrences)×")
            .font(.system(size: 12, weight: occurrences > 2 ? .bold : .semibold))
            .monospacedDigit()
            .foregroundStyle(Theme.heat(occurrences))
    }
}

struct Tag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.fg2)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .kerning(1.7)
            .foregroundStyle(Theme.fg3)
    }
}

/// A row in the question bank.
struct QuestionRow: View {
    let cluster: QuestionCluster

    private var yearText: String {
        cluster.years.map { String($0 % 100) }.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            HeatRail(occurrences: cluster.occurrences)
            VStack(alignment: .leading, spacing: 8) {
                Text(cluster.canonicalText)
                    .font(Theme.serif(16.5))
                    .foregroundStyle(cluster.occurrences > 1 ? Theme.fg : Theme.fg2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 9) {
                    HeatLabel(occurrences: cluster.occurrences)
                    Circle().fill(Theme.line).frame(width: 3, height: 3)
                    Text(yearText)
                        .font(.system(size: 11.5))
                        .monospacedDigit()
                        .foregroundStyle(Theme.fg3)
                    Spacer(minLength: 6)
                    if let unit = cluster.unitNumber, let marks = cluster.typicalMarks {
                        Tag(text: "U\(unit) · \(marks)m")
                    }
                }
            }
        }
        .padding(.vertical, 13)
        .fixedSize(horizontal: false, vertical: true)
    }
}
