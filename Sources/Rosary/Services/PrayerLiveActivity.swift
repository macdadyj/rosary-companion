#if os(iOS)
import ActivityKit
import Foundation
import RosaryCore

enum PrayerLiveActivity {
    static func sync(title: String, detail: String, completed: Int, total: Int) {
        let state = PrayerActivityAttributes.ContentState(
            title: title, detail: detail, completed: completed, total: max(total, 1)
        )
        if let activity = Activity<PrayerActivityAttributes>.activities.first {
            Task { await activity.update(using: state) }
            return
        }
        let attributes = PrayerActivityAttributes(devotionName: "Rosary")
        _ = try? Activity.request(attributes: attributes, contentState: state, pushType: nil)
    }

    static func end() {
        let activities = Activity<PrayerActivityAttributes>.activities
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
