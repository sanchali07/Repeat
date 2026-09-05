import SwiftUI

/// Edits the paper, not a settings form. The marks total is the biggest thing on
/// screen and moves the moment a stepper is touched.
struct PatternEditorView: View {
    @EnvironmentObject private var library: Library
    @State private var showPaper = false

    private var presets: [(String, ExamPattern)] {
        [("MST-1", .mst1(units: [1, 2])),
         ("MST-2", .mst2(units: [3, 4])),
         ("End Sem", .endSemester(unitCount: library.syllabus.units.count))]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.ink.ignoresSafeArea()
                VStack(spacing: 0) {
                    presetPicker
                    total
                    ScrollView {
                        VStack(spacing: 11) {
                            ForEach(Array(library.pattern.sections.enumerated()), id: \.element.id) { index, _ in
                                sectionCard(index: index)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                    generateButton
                }
            }
            .foregroundStyle(Theme.fg)
            .navigationDestination(isPresented: $showPaper) {
                PaperView(paper: library.generate())
            }
        }
    }

    private var presetPicker: some View {
        HStack(spacing: 7) {
            ForEach(presets, id: \.0) { name, preset in
                let active = library.pattern.name == preset.name
                Button {
                    library.pattern = preset
                } label: {
                    Text(name)
                        .font(.system(size: 12.5, weight: active ? .semibold : .regular))
                        .foregroundStyle(active ? Theme.paperInk : Theme.fg2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(active ? Theme.paper : .clear,
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    private var total: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(library.pattern.totalMarks)")
                .font(Theme.serif(46, .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.25), value: library.pattern.totalMarks)
            Text("marks")
                .font(.system(size: 13))
                .foregroundStyle(Theme.fg3)
            Spacer()
            Text(durationText)
                .font(.system(size: 13))
                .foregroundStyle(Theme.fg2)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Divider().overlay(Theme.line) }
    }

    private var durationText: String {
        let minutes = library.pattern.durationMinutes
        if minutes % 60 == 0 { return "\(minutes / 60) hours" }
        return String(format: "%.1f hours", Double(minutes) / 60)
    }

    private func sectionCard(index: Int) -> some View {
        let section = library.pattern.sections[index]
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(section.name)
                    .font(.system(size: 13.5, weight: .semibold))
                Spacer()
                Text("\(section.attemptableMarks) marks")
                    .font(.system(size: 12.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.paper)
            }

            stepper("Questions", value: section.slotCount) { delta in
                let new = max(1, min(30, section.slotCount + delta))
                library.pattern.sections[index].slotCount = new
                if case .answerAny(let answer, _) = section.choiceStyle {
                    library.pattern.sections[index].choiceStyle =
                        .answerAny(answer: min(answer, new), printed: new)
                }
            }

            stepper("Marks each", value: section.marksPerQuestion) { delta in
                library.pattern.sections[index].marksPerQuestion =
                    max(1, min(30, section.marksPerQuestion + delta))
            }

            HStack(spacing: 10) {
                Text("Choice")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.fg2)
                    .frame(width: 72, alignment: .leading)
                HStack(spacing: 6) {
                    choiceButton("all", isActive: isNone(section.choiceStyle)) {
                        library.pattern.sections[index].choiceStyle = .none
                    }
                    choiceButton("(a) or (b)", isActive: isInternal(section.choiceStyle)) {
                        library.pattern.sections[index].choiceStyle = .internalChoice
                    }
                    choiceButton("any n", isActive: isAny(section.choiceStyle)) {
                        let printed = section.slotCount
                        library.pattern.sections[index].choiceStyle =
                            .answerAny(answer: max(1, printed - 1), printed: printed)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private func isNone(_ style: ChoiceStyle) -> Bool { if case .none = style { true } else { false } }
    private func isInternal(_ style: ChoiceStyle) -> Bool { if case .internalChoice = style { true } else { false } }
    private func isAny(_ style: ChoiceStyle) -> Bool { if case .answerAny = style { true } else { false } }

    private func stepper(_ label: String, value: Int, change: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.fg2)
                .frame(width: 72, alignment: .leading)
            HStack(spacing: 0) {
                Button { change(-1) } label: {
                    Image(systemName: "minus").font(.system(size: 13, weight: .medium))
                        .frame(width: 40, height: 34).foregroundStyle(Theme.fg2)
                }
                Text("\(value)")
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                Button { change(1) } label: {
                    Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                        .frame(width: 40, height: 34).foregroundStyle(Theme.fg)
                }
            }
            .buttonStyle(.plain)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
        }
    }

    private func choiceButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Theme.paperInk : Theme.fg2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isActive ? Theme.paper : Theme.ink,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isActive ? .clear : Theme.line))
        }
        .buttonStyle(.plain)
    }

    private var generateButton: some View {
        Button { showPaper = true } label: {
            Text("Generate paper")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.paperInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }
}
