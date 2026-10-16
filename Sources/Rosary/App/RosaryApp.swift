#if os(iOS)
import RosaryCore
import SwiftUI

@main
struct RosaryApp: App {
    @State private var model: AppModel
    private let library: SaintsLibrary
    private let content: PrayerContent?

    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
        let store = testing ? nil : (try? JSONFileStore.applicationSupport())
        let model = AppModel(store: store)
        if testing {
            model.update { $0.voiceTracking = false }
        }
        // If Application Support is unavailable the app still runs; changes just aren't saved.
        _model = State(initialValue: model)
        library = (try? SaintsLibrary.bundled()) ?? .empty
        content = try? PrayerContent.bundled()
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model, library: library, content: content)
        }
    }
}
#endif
