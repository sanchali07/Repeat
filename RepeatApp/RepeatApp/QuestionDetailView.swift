import SwiftUI

struct QuestionDetailView: View {
    let cluster: QuestionCluster
    @EnvironmentObject private var library: Library

    /// Six years of history, so the gaps are as visible as the hits.
    private var timeline: [(year: Int, hit: Bool)] {
        let thisYear = Calendar.current.component(.year, from: .now)
        return ((thisYear - 6)...(thisYear - 1)).map { ($0, cluster.years.contains($0)) }
    }

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 16) {
                        Text(cluster.canonicalText)
                            .font(Theme.serif(24, .medium))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Text(cluster.occurrences == 1 ? "ASKED ONCE" : "ASKED \(cluster.occurrences)×")
                                .font(.system(size: 11.5, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.paperInk)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.heat(cluster.occurrences),
                                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            if let unit = cluster.unitNumber { Tag(text: "Unit \(unit)") }
                            if let topic = cluster.topicKey { Tag(text: topic) }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "APPEARANCES")
                        HStack(alignment: .bottom, spacing: 7) {
                            ForEach(timeline, id: \.year) { entry in
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(entry.hit ? Theme.heat(cluster.occurrences) : Theme.raised)
                                        .frame(height: entry.hit ? 52 : 10)
                                    Text(String(entry.year % 100))
                                        .font(.system(size: 10))
                                        .monospacedDigit()
                                        .foregroundStyle(entry.hit ? Theme.fg2 : Theme.fg3)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 74, alignment: .bottom)

                        HStack(spacing: 22) {
                            if let marks = cluster.typicalMarks {
                                stat("\(marks)", "usual marks")
                            }
                            stat("\(cluster.years.count) of 6", "recent years")
                        }
                        .padding(.top, 4)
                    }

                    VStack(alignment: .leading, spacing: 11) {
                        SectionLabel(text: "HOW IT WAS WORDED")
                        ForEach(cluster.variants) { variant in
                            HStack(alignment: .top, spacing: 11) {
                                Text(variant.year.map(String.init) ?? "—")
                                    .font(.system(size: 10.5))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.fg3)
                                    .padding(.top, 2)
                                Text(variant.text)
                                    .font(Theme.serif(13.5))
                                    .foregroundStyle(Theme.fg2)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(13)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.line))
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
        }
        .foregroundStyle(Theme.fg)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.fg3)
        }
    }
}
