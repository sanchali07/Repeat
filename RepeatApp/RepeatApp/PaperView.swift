import SwiftUI

/// Ink becomes paper. Serif throughout, real exam furniture, and one heat dot per
/// question so you can still see why it was chosen.
struct PaperView: View {
    let paper: GeneratedPaper

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        masthead
                        ForEach(paper.sections) { section in
                            sectionView(section)
                        }
                        if !paper.warnings.isEmpty {
                            warnings
                        }
                    }
                    .padding(26)
                }
                .background(Theme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)

                exportBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var durationText: String {
        let minutes = paper.durationMinutes
        if minutes % 60 == 0 { return "\(minutes / 60) hours" }
        return String(format: "%.1f hours", Double(minutes) / 60)
    }

    private var masthead: some View {
        VStack(spacing: 3) {
            Text("\(paper.subjectCode) — \(paper.subject.uppercased())")
                .font(Theme.serif(14.5, .semibold))
                .kerning(0.4)
            Text(paper.patternName.uppercased())
                .font(Theme.serif(10.5))
                .kerning(1.5)
                .foregroundStyle(Theme.paperInk.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 13)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.paperInk).frame(height: 1.5)
        }
        .foregroundStyle(Theme.paperInk)
        .overlay(alignment: .bottom) {
            HStack {
                Text("Time: \(durationText)")
                Spacer()
                Text("Maximum: \(paper.totalMarks) marks")
            }
            .font(Theme.serif(11))
            .foregroundStyle(Theme.paperInk.opacity(0.75))
            .offset(y: 26)
        }
        .padding(.bottom, 40)
    }

    private func sectionView(_ section: GeneratedSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(section.name.uppercased()) — (\(section.slots.count) × \(section.marksPerQuestion) = \(section.attemptableMarks) marks)")
                .font(Theme.serif(11.5, .semibold))
                .kerning(0.5)
            Text(section.instruction)
                .font(Theme.serif(10.5).italic())
                .foregroundStyle(Theme.paperInk.opacity(0.6))
                .padding(.top, 3)
                .padding(.bottom, 11)

            ForEach(section.slots) { slot in
                ForEach(Array(slot.alternatives.enumerated()), id: \.element.id) { index, alternative in
                    questionLine(slot: slot, index: index, alternative: alternative)
                    if index < slot.alternatives.count - 1 {
                        Text("Or")
                            .font(Theme.serif(11).italic())
                            .foregroundStyle(Theme.paperInk.opacity(0.6))
                            .padding(.leading, 42)
                            .padding(.vertical, 4)
                    }
                }
                Spacer().frame(height: 9)
            }
        }
        .foregroundStyle(Theme.paperInk)
        .padding(.bottom, 20)
    }

    private func questionLine(slot: PaperSlot, index: Int, alternative: PaperAlternative) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label(slot: slot, index: index, alternative: alternative))
                .font(Theme.serif(12))
                .frame(width: alternative.letter == nil ? 20 : 40, alignment: .leading)
            Text(alternative.text)
                .font(Theme.serif(12))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if alternative.occurrences > 0 {
                Circle()
                    .fill(Theme.heat(alternative.occurrences))
                    .frame(width: 5, height: 5)
                    .padding(.top, 5)
            }
            Text("(\(alternative.marks))")
                .font(Theme.serif(11))
                .foregroundStyle(Theme.paperInk.opacity(0.75))
        }
    }

    private func label(slot: PaperSlot, index: Int, alternative: PaperAlternative) -> String {
        guard let letter = alternative.letter else { return "\(slot.number)." }
        return index == 0 ? "\(slot.number). (\(letter))" : "     (\(letter))"
    }

    private var warnings: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COULD NOT FILL")
                .font(.system(size: 9.5, weight: .bold))
                .kerning(1.4)
            ForEach(paper.warnings, id: \.self) { warning in
                Text("• \(warning)")
                    .font(.system(size: 10.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.paperInk.opacity(0.65))
        .padding(.top, 8)
    }

    private var exportBar: some View {
        HStack(spacing: 10) {
            Text("Export PDF")
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(Theme.paperInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 4)
    }
}
