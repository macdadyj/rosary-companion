#if os(iOS)
import RosaryCore
import SwiftUI

/// True when this process was launched by the phone UI tests.
enum UITestLaunch {
    static var isEnabled: Bool {
        let process = ProcessInfo.processInfo
        if process.arguments.contains("--uitesting") { return true }
        return process.environment["XCTestConfigurationFilePath"] != nil
    }
}

@main
struct RosaryApp: App {
    @State private var model: AppModel
    @State private var art: SacredArtLibrary
    private let library: SaintsLibrary
    private let content: PrayerContent?

    init() {
        let testing = UITestLaunch.isEnabled
        let store = testing ? nil : (try? JSONFileStore.applicationSupport())
        let model = AppModel(store: store)
        if testing {
            model.update { $0.voiceTracking = false }
        }
        // If Application Support is unavailable the app still runs; changes just aren't saved.
        _model = State(initialValue: model)
        _art = State(initialValue: SacredArtLibrary.live())
        library = (try? SaintsLibrary.bundled()) ?? .empty
        content = try? PrayerContent.bundled()
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model, library: library, art: art, content: content)
        }
    }
}
#endif
