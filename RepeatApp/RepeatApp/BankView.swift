import SwiftUI

struct BankView: View {
    @EnvironmentObject private var library: Library
    @State private var unitFilter: Int?
    @State private var marksFilter: Int?

    private var visible: [QuestionCluster] {
        library.clusters.filter { cluster in
            (unitFilter == nil || cluster.unitNumber == unitFilter)
                && (marksFilter == nil || cluster.typicalMarks == marksFilter)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.ink.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            SectionLabel(text: "MOST LIKELY")
                                .padding(.top, 15)
                                .padding(.bottom, 4)
                            ForEach(visible) { cluster in
                                NavigationLink {
                                    QuestionDetailView(cluster: cluster)
                                } label: {
                                    QuestionRow(cluster: cluster)
                                }
                                .buttonStyle(.plain)
                                Divider().overlay(Theme.line.opacity(0.55))
                            }
                        }
                        .padding(.horizontal, 22)
                    }
                }
            }
            .foregroundStyle(Theme.fg)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Question bank")
                    .font(Theme.serif(27, .medium))
                Spacer()
                Text("\(visible.count)")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.fg3)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All units", active: unitFilter == nil) { unitFilter = nil }
                    ForEach(library.syllabus.units, id: \.number) { unit in
                        chip("Unit \(unit.number)", active: unitFilter == unit.number) {
                            unitFilter = unitFilter == unit.number ? nil : unit.number
                        }
                    }
                    chip("16 marks", active: marksFilter == 16) {
                        marksFilter = marksFilter == 16 ? nil : 16
                    }
                    chip("2 marks", active: marksFilter == 2) {
                        marksFilter = marksFilter == 2 ? nil : 2
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Divider().overlay(Theme.line) }
    }

    private func chip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Theme.paperInk : Theme.fg2)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(active ? Theme.paper : Theme.raised,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(active ? .clear : Theme.line)
                )
        }
        .buttonStyle(.plain)
    }
}
