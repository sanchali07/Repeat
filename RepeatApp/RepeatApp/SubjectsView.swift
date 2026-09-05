import SwiftUI

struct SubjectsView: View {
    @EnvironmentObject private var library: Library

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.ink.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Subjects")
                                .font(Theme.serif(38, .medium))
                            Text("\(library.paperCount) papers analysed")
                                .font(.system(size: 13.5))
                                .foregroundStyle(Theme.fg3)
                        }

                        subjectCard
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                }
            }
            .foregroundStyle(Theme.fg)
        }
    }

    private var hottest: Int {
        library.clusters.map(\.occurrences).max() ?? 0
    }

    private var subjectCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(library.syllabus.subject)
                        .font(Theme.serif(21, .medium))
                    Text("\(library.syllabus.code) · SEM 6")
                        .font(.system(size: 11.5, weight: .medium))
                        .kerning(0.6)
                        .foregroundStyle(Theme.fg3)
                }
                Spacer()
                Text("\(hottest) REPEATS")
                    .font(.system(size: 10.5, weight: .bold))
                    .kerning(0.4)
                    .foregroundStyle(Theme.paperInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Theme.heat(hottest), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            // Bar height is how many questions the unit produced; bar colour is
            // how hot its hottest repeat is.
            HStack(alignment: .bottom, spacing: 5) {
                let counts = library.countsByUnit()
                let maxCount = max(1, counts.map(\.count).max() ?? 1)
                ForEach(counts, id: \.unit) { entry in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.heat(entry.hottest))
                        .frame(height: max(8, 44 * CGFloat(entry.count) / CGFloat(maxCount)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 44)

            Divider().overlay(Theme.line)

            HStack {
                Text("\(library.clusters.count) distinct questions")
                    .font(.system(size: 12.5))
                    .monospacedDigit()
                    .foregroundStyle(Theme.fg2)
                Spacer()
                Text("\(library.syllabus.units.count) units")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.fg3)
            }
        }
        .padding(18)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line))
    }
}
