#if os(iOS)
import RosaryCore
import SwiftUI

struct RootView: View {
    let model: AppModel
    let library: SaintsLibrary

    @State private var activeSession: ActiveSession?

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(model: model, onBegin: begin)
            }
            .tabItem { Label("Pray", systemImage: "hands.sparkles") }

            NavigationStack { IntentionsView(model: model) }
                .tabItem { Label("Intentions", systemImage: "heart.text.square") }

            NavigationStack { JournalView(model: model) }
                .tabItem { Label("Journal", systemImage: "book.closed") }

            NavigationStack { SaintsLibraryView(library: library) }
                .tabItem { Label("Saints", systemImage: "quote.bubble") }

            NavigationStack { SettingsView(model: model) }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.gold)
        .preferredColorScheme(model.settings.appearance.colorScheme)
        .fullScreenCover(item: $activeSession) { session in
            SessionView(session: session, settings: model.settings, library: library) {
                activeSession = nil
            }
        }
    }

    private func begin(_ setup: SessionSetup) {
        activeSession = ActiveSession(prepared: model.prepare(setup), model: model)
    }
}
#endif
