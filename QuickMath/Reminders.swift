import Foundation
import UserNotifications

/// Optional local daily-drill reminder. This is the ONLY device permission the app ever requests,
/// it is non-core (the drills work without it), and it is purely on-device — no servers.
enum Reminders {
    private static let identifier = "quickmath.daily.reminder"

    /// Ask for notification permission. Returns whether it was granted.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Schedule a repeating daily reminder at the given local time.
    static func schedule(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Time for your QuickMath drill"
        content.body = "Three quick rounds. Keep your streak alive."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
