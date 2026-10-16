#if os(iOS)
import RosaryCore
import SwiftUI

struct RootView: View {
    let model: AppModel
    let library: SaintsLibrary
    let content: PrayerContent?

    @State private var activeSession: ActiveSession?

    private var uiTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    var body: some View {
        if uiTesting, let session = activeSession {
            // UI tests on the iOS 26 simulator never see a fullScreenCover, so the
            // prayer screen replaces the tabs for that launch argument only.
            SessionView(session: session, settings: model.settings, library: library, content: content) {
                activeSession = nil
            }
        } else {
            tabs
        }
    }

    private var tabs: some View {
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
