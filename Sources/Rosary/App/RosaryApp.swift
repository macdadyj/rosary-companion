#if os(iOS)
import RosaryCore
import SwiftUI

@main
struct RosaryApp: App {
    @State private var model: AppModel
    private let library: SaintsLibrary

    init() {
        // If Application Support is unavailable the app still runs; changes just aren't saved.
        _model = State(initialValue: AppModel(store: try? JSONFileStore.applicationSupport()))
        library = (try? SaintsLibrary.bundled()) ?? .empty
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model, library: library)
        }
    }
}
#endif
