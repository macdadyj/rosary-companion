#if os(iOS)
import RosaryCore
import SwiftUI

struct RootView: View {
    let model: AppModel
    let library: SaintsLibrary
    let content: PrayerContent?

    @State private var activeSession: ActiveSession?

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(model: model, content: content, onBegin: begin)
            }
            .tabItem { Label("Pray", systemImage: "hands.sparkles") }
            .uiTag(UITag.tabPray)

            NavigationStack { DevotionsView(model: model, content: content) }
                .tabItem { Label("Devotions", systemImage: "flame") }
                .uiTag(UITag.tabDevotions)

            NavigationStack { IntentionsView(model: model) }
                .tabItem { Label("Intentions", systemImage: "heart.text.square") }
                .uiTag(UITag.tabIntentions)

            NavigationStack { SaintsLibraryView(library: library, content: content) }
                .tabItem { Label("Saints", systemImage: "quote.bubble") }
                .uiTag(UITag.tabSaints)

            NavigationStack { SettingsView(model: model, content: content) }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .uiTag(UITag.tabSettings)
        }
        .tint(Theme.gold)
        .preferredColorScheme(model.settings.appearance.colorScheme)
        .fullScreenCover(item: $activeSession) { session in
            SessionView(session: session, settings: model.settings, library: library, content: content) {
                activeSession = nil
            }
        }
    }

    private func begin(_ setup: SessionSetup) {
        activeSession = ActiveSession(prepared: model.prepare(setup), model: model)
    }
}
#endif
