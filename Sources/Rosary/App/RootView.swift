#if os(iOS)
import RosaryCore
import SwiftUI

struct RootView: View {
    let model: AppModel
    let library: SaintsLibrary
    let content: PrayerContent?

    @State private var activeSession: ActiveSession?

    var body: some View {
        if UITestLaunch.isEnabled, let session = activeSession {
            // UI tests on the iOS 26 simulator never see a fullScreenCover, so the
            // prayer screen replaces the tabs for that launch only.
            sessionScreen(session)
        } else {
            tabs
        }
    }

    private func sessionScreen(_ session: ActiveSession) -> some View {
        SessionView(session: session, settings: model.settings, library: library, content: content) {
            activeSession = nil
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
            sessionScreen(session)
        }
    }

    private func begin(_ setup: SessionSetup) {
        let session = ActiveSession(prepared: model.prepare(setup), model: model)
        if UITestLaunch.isEnabled {
            // Swapping the tabs out for the prayer screen inside this button's
            // action drops the state update, so the session never appears.
            Task { @MainActor in activeSession = session }
        } else {
            activeSession = session
        }
    }
}
#endif
