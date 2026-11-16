import Foundation
import UserNotifications

/// The daily reminder: one local notification at the learner's chosen time. Asks for
/// permission the first time it is switched on; nothing leaves the phone.
enum ReminderScheduler {
    static let id = "daily-reminder"

    /// Turns the reminder on. Returns false if the learner said no to notifications.
    static func enable(hour: Int, minute: Int, name: String) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = name.isEmpty ? "გამარჯობა!" : "გამარჯობა, \(name)!"
        content.body = "A few minutes of Georgian keeps your streak alive."
        content.sound = .default
        var when = DateComponents()
        when.hour = hour
        when.minute = minute
        let request = UNNotificationRequest(identifier: id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
