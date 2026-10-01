#if os(iOS)
import SwiftUI
import RosaryCore

@main
struct RosaryApp: App {
    var body: some Scene {
        WindowGroup {
            Text(MysterySet.joyful.title)
        }
    }
}
#endif
