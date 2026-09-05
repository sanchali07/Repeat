import SwiftUI

struct RootView: View {
    @StateObject private var library = Library()

    var body: some View {
        TabView {
            SubjectsView()
                .tabItem { Label("Subjects", systemImage: "rectangle.grid.1x2") }
            BankView()
                .tabItem { Label("Bank", systemImage: "list.bullet") }
            PatternEditorView()
                .tabItem { Label("Generate", systemImage: "doc.text") }
        }
        .environmentObject(library)
        .tint(Theme.paper)
    }
}
