#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

public struct PrayerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var title: String
        public var detail: String
        public var completed: Int
        public var total: Int

        public init(title: String, detail: String, completed: Int, total: Int) {
            self.title = title
            self.detail = detail
            self.completed = completed
            self.total = total
        }
    }

    public var devotionName: String

    public init(devotionName: String) {
        self.devotionName = devotionName
    }
}
#endif
