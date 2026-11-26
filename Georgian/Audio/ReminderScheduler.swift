import Foundation
import UserNotifications

/// The daily reminder: a local notification at the learner's chosen time, only on days they
/// haven't practised yet (KART #16). iOS can't skip a day of a repeating notification, so
/// the next two weeks are scheduled one by one and refreshed whenever the app opens or a
/// lesson or review is finished: today's goes once the learner has practised. Someone away
/// for longer than two weeks stops being reminded until they come back. Asks for permission
/// the first time it's switched on; nothing leaves the phone.
enum ReminderScheduler {
    /// Days scheduled ahead (iOS keeps at most 64 pending notifications per app).
    static let daysAhead = 14
    private static let prefix = "daily-reminder"

    private static func id(_ day: Int) -> String { "\(prefix)-\(day)" }
    /// Every id this app has used, including the single repeating one before KART #16.
    private static var allIDs: [String] { [prefix] + (0..<daysAhead).map(id) }

    /// Turns the reminder on, asking for permission if needed. Returns false if notifications
    /// aren't allowed.
    static func enable(hour: Int, minute: Int, name: String, practisedToday: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        return await schedule(hour: hour, minute: minute, name: name, practisedToday: practisedToday)
    }

    /// Schedules the next two weeks again (after a lesson, at launch, after a change of time
    /// or language) without asking for anything. Returns false when notifications are no
    /// longer allowed (switched off in the iPhone's Settings).
    static func refresh(hour: Int, minute: Int, name: String, practisedToday: Bool) async -> Bool {
        guard await isAllowed() else {
            disable()
            return false
        }
        _ = await schedule(hour: hour, minute: minute, name: name, practisedToday: practisedToday)
        return true
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIDs)
    }

    static func isAllowed() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    private static func schedule(hour: Int, minute: Int, name: String, practisedToday: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
        let content = UNMutableNotificationContent()
        content.title = name.isEmpty ? "გამარჯობა!" : "გამარჯობა, \(name)!"
        content.body = tr("Ara is waiting: a few minutes of Georgian keeps your streak alive.")
        content.sound = .default
        let calendar = Calendar.current
        var ok = true
        for (i, date) in ReminderPlan.dates(hour: hour, minute: minute, practisedToday: practisedToday, days: daysAhead).enumerated() {
            let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let request = UNNotificationRequest(identifier: id(i), content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
            do { try await center.add(request) } catch { ok = false }
        }
        return ok
    }
}
