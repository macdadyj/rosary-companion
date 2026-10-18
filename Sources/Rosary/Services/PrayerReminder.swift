#if os(iOS)
import Foundation
import UserNotifications

/// One repeating local notification. It is scheduled only after the Settings switch is turned on.
enum PrayerReminder {
    static let identifier = "rosary.daily"

    static func schedule(enabled: Bool, hour: Int, minute: Int, body: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return }
        let settings = await center.notificationSettings()
        let allowed: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            allowed = true
        case .notDetermined:
            allowed = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            allowed = false
        @unknown default:
            allowed = false
        }
        guard allowed else { return }
        let content = UNMutableNotificationContent()
        content.title = "Pray the Rosary"
        content.body = body
        content.sound = .default
        var when = DateComponents()
        when.hour = hour
        when.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
#endif
