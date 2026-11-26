import Foundation

/// Which days the daily reminder comes on (KART #16): the next `days` days at the chosen
/// time, leaving out today once the learner has practised or the time has passed. The
/// scheduling itself is in Audio/ReminderScheduler.swift; this part is pure, so it's tested.
enum ReminderPlan {
    static func dates(hour: Int, minute: Int, practisedToday: Bool, days: Int, now: Date = Date(),
                      calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<max(0, days)).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let at = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { return nil }
            if offset == 0 && (practisedToday || at <= now) { return nil }
            return at
        }
    }
}
