import Foundation

/// A calendar day in the learner's own time zone, as "yyyy-MM-dd".
enum DayKey {
    static func of(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func adding(_ days: Int, to key: String, calendar: Calendar = .current) -> String {
        guard let d = date(key, calendar: calendar), let n = calendar.date(byAdding: .day, value: days, to: d) else { return key }
        return of(n, calendar: calendar)
    }

    static func date(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    /// The last `count` days ending today, oldest first.
    static func lastDays(_ count: Int, endingOn today: String, calendar: Calendar = .current) -> [String] {
        (0..<count).reversed().map { adding(-$0, to: today, calendar: calendar) }
    }
}

/// How much XP things are worth.
enum XPRules {
    static let lessonComplete = 10
    static let perAnswer = 1
    static let perfectBonus = 5
    static let reviewComplete = 5
    static let challengeBonus = 10

    static func lesson(_ s: SessionSummary) -> Int {
        lessonComplete + s.correctFirstTry * perAnswer + (s.isPerfect ? perfectBonus : 0)
    }

    static func review(_ s: SessionSummary) -> Int {
        reviewComplete + s.correctFirstTry * perAnswer
    }
}

/// The daily goal choices, in XP.
enum DailyGoal: Int, CaseIterable, Identifiable {
    case casual = 10, regular = 20, serious = 30, intense = 50

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .casual: return tr("Casual")
        case .regular: return tr("Regular")
        case .serious: return tr("Serious")
        case .intense: return tr("Intense")
        }
    }
    var minutes: String {
        switch self {
        case .casual: return tr("about 5 minutes a day")
        case .regular: return tr("about 10 minutes a day")
        case .serious: return tr("about 15 minutes a day")
        case .intense: return tr("about 25 minutes a day")
        }
    }
}

enum Streak {
    /// Days in a row with some XP, ending today, or yesterday when today has none yet (the
    /// streak is still alive until the day is over).
    static func current(activeDays: Set<String>, today: String, calendar: Calendar = .current) -> Int {
        var day = activeDays.contains(today) ? today : DayKey.adding(-1, to: today, calendar: calendar)
        var n = 0
        while activeDays.contains(day) {
            n += 1
            day = DayKey.adding(-1, to: day, calendar: calendar)
        }
        return n
    }

    static func longest(activeDays: Set<String>, calendar: Calendar = .current) -> Int {
        var best = 0
        for day in activeDays where !activeDays.contains(DayKey.adding(-1, to: day, calendar: calendar)) {
            var n = 0
            var d = day
            while activeDays.contains(d) {
                n += 1
                d = DayKey.adding(1, to: d, calendar: calendar)
            }
            best = max(best, n)
        }
        return best
    }
}

/// Levels from XP: each level needs a little more than the last.
enum LearnerLevel {
    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xp >= threshold(level + 1) { level += 1 }
        return level
    }

    /// XP needed to reach a level (level 1 starts at 0; then 50, 120, 210, …).
    static func threshold(_ level: Int) -> Int {
        guard level > 1 else { return 0 }
        let n = level - 1
        return 50 * n + 10 * n * (n - 1)
    }

    /// Progress through the current level, 0 to 1.
    static func progress(forXP xp: Int) -> Double {
        let l = level(forXP: xp)
        let lo = threshold(l), hi = threshold(l + 1)
        return Double(xp - lo) / Double(max(1, hi - lo))
    }
}

/// Everything the achievements, challenges and statistics are worked out from.
struct ProgressSnapshot: Equatable {
    var totalXP = 0
    /// XP per day key.
    var xpByDay: [String: Int] = [:]
    var lessonsCompleted: Set<String> = []
    var perfectLessons = 0
    var wordsLearned = 0
    var lettersLearned = 0
    var reviewSessions = 0
    var dailyGoal = 20
    /// Modules whose every lesson is done.
    var modulesCompleted: Set<String> = []
    var today = ""

    var activeDays: Set<String> { Set(xpByDay.filter { $0.value > 0 }.keys) }
    var streak: Int { Streak.current(activeDays: activeDays, today: today) }
    var longestStreak: Int { Streak.longest(activeDays: activeDays) }
    var goalDays: Int { xpByDay.values.filter { $0 >= dailyGoal }.count }
    var xpToday: Int { xpByDay[today] ?? 0 }
}

struct Achievement: Identifiable, Hashable {
    let id: String
    /// English; shown through `title` and `detail` in the learner's language.
    let titleEN: String
    let detailEN: String
    let symbol: String
    let color: String
    /// How far towards it, 0…1.
    let progress: (ProgressSnapshot) -> Double

    static func == (a: Achievement, b: Achievement) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var title: String { tr(titleEN) }
    var detail: String { tr(detailEN) }

    func isUnlocked(_ s: ProgressSnapshot) -> Bool { progress(s) >= 1 }

    static func ratio(_ value: Int, _ target: Int) -> Double { min(1, Double(value) / Double(target)) }

    static let all: [Achievement] = [
        Achievement(id: "first-lesson", titleEN: "First steps", detailEN: "Finish your first lesson", symbol: "figure.walk", color: "tkemali",
                    progress: { Achievement.ratio($0.lessonsCompleted.count, 1) }),
        Achievement(id: "letters-10", titleEN: "Ten letters", detailEN: "Learn 10 letters", symbol: "textformat", color: "blacksea",
                    progress: { Achievement.ratio($0.lettersLearned, 10) }),
        Achievement(id: "alphabet", titleEN: "ანბანი", detailEN: "Finish the whole alphabet module", symbol: "character.book.closed.fill", color: "pomegranate",
                    progress: { $0.modulesCompleted.contains("alphabet") ? 1 : 0 }),
        Achievement(id: "perfect", titleEN: "Flawless", detailEN: "Finish a lesson without a mistake", symbol: "sparkles", color: "gold",
                    progress: { Achievement.ratio($0.perfectLessons, 1) }),
        Achievement(id: "streak-3", titleEN: "On a roll", detailEN: "Learn 3 days in a row", symbol: "flame.fill", color: "pomegranate",
                    progress: { Achievement.ratio($0.longestStreak, 3) }),
        Achievement(id: "streak-7", titleEN: "One week", detailEN: "Learn 7 days in a row", symbol: "flame.fill", color: "gold",
                    progress: { Achievement.ratio($0.longestStreak, 7) }),
        Achievement(id: "streak-30", titleEN: "A month of Georgian", detailEN: "Learn 30 days in a row", symbol: "crown.fill", color: "saperavi",
                    progress: { Achievement.ratio($0.longestStreak, 30) }),
        Achievement(id: "words-25", titleEN: "Word collector", detailEN: "Learn 25 words", symbol: "text.book.closed.fill", color: "tkemali",
                    progress: { Achievement.ratio($0.wordsLearned, 25) }),
        Achievement(id: "words-100", titleEN: "Wordsmith", detailEN: "Learn 100 words", symbol: "books.vertical.fill", color: "saperavi",
                    progress: { Achievement.ratio($0.wordsLearned, 100) }),
        Achievement(id: "numbers", titleEN: "Count to a hundred", detailEN: "Finish How numbers are built", symbol: "number", color: "gold",
                    progress: { $0.lessonsCompleted.contains("v6c") ? 1 : 0 }),
        Achievement(id: "cafe", titleEN: "Order in a café", detailEN: "Finish the café conversation", symbol: "cup.and.saucer.fill", color: "pomegranate",
                    progress: { $0.lessonsCompleted.contains("c1") ? 1 : 0 }),
        Achievement(id: "grammar", titleEN: "Your own sentences", detailEN: "Finish the Grammar module", symbol: "puzzlepiece.fill", color: "blacksea",
                    progress: { $0.modulesCompleted.contains("grammar") ? 1 : 0 }),
        Achievement(id: "goal-7", titleEN: "Goal getter", detailEN: "Reach your daily goal on 7 days", symbol: "target", color: "blacksea",
                    progress: { Achievement.ratio($0.goalDays, 7) }),
        Achievement(id: "review-10", titleEN: "Never forget", detailEN: "Finish 10 review sessions", symbol: "arrow.triangle.2.circlepath", color: "saperavi",
                    progress: { Achievement.ratio($0.reviewSessions, 10) }),
        Achievement(id: "everyday", titleEN: "Ready for Tbilisi", detailEN: "Finish Everyday Georgian", symbol: "map.fill", color: "gold",
                    progress: { $0.modulesCompleted.contains("everyday") ? 1 : 0 }),
        Achievement(id: "conversation", titleEN: "Chatterbox", detailEN: "Finish every conversation", symbol: "bubble.left.and.bubble.right.fill", color: "tkemali",
                    progress: { $0.modulesCompleted.contains("conversation") ? 1 : 0 }),
    ]

    /// Achievements reached in `after` that weren't in `before`.
    static func newlyUnlocked(before: ProgressSnapshot, after: ProgressSnapshot, alreadyRecorded: Set<String>) -> [Achievement] {
        all.filter { !alreadyRecorded.contains($0.id) && $0.isUnlocked(after) && !$0.isUnlocked(before) }
            + all.filter { !alreadyRecorded.contains($0.id) && $0.isUnlocked(after) && $0.isUnlocked(before) }
    }
}

/// Today's extra task: one of four, chosen by the date so it stays the same all day.
struct DailyChallenge: Equatable {
    enum Kind: Int, CaseIterable { case doubleGoal, perfectLesson, review, twoLessons }

    let kind: Kind
    let target: Int

    static func of(day: String, dailyGoal: Int) -> DailyChallenge {
        let seed = day.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
        let kind = Kind.allCases[Int(seed.magnitude % UInt(Kind.allCases.count))]
        switch kind {
        case .doubleGoal: return DailyChallenge(kind: kind, target: dailyGoal * 2)
        case .perfectLesson: return DailyChallenge(kind: kind, target: 1)
        case .review: return DailyChallenge(kind: kind, target: 10)
        case .twoLessons: return DailyChallenge(kind: kind, target: 2)
        }
    }

    var title: String {
        switch kind {
        case .doubleGoal: return tr("Earn {0} XP today", target)
        case .perfectLesson: return tr("Finish a lesson without a mistake")
        case .review: return tr("Review {0} words or letters", target)
        case .twoLessons: return tr("Finish 2 lessons")
        }
    }

    var symbol: String {
        switch kind {
        case .doubleGoal: return "bolt.fill"
        case .perfectLesson: return "sparkles"
        case .review: return "arrow.triangle.2.circlepath"
        case .twoLessons: return "flag.checkered"
        }
    }

    /// Progress from today's numbers.
    func value(xp: Int, perfectLessons: Int, reviewed: Int, lessons: Int) -> Int {
        switch kind {
        case .doubleGoal: return xp
        case .perfectLesson: return perfectLessons
        case .review: return reviewed
        case .twoLessons: return lessons
        }
    }
}

/// Where each lesson stands on the learning path.
enum LessonState: Equatable {
    case completed, current, available, locked
}

enum CourseProgress {
    /// Lessons are done in order. The first one not done (from `startIndex`) is "current";
    /// the ones after it are locked, except those before `openBefore`, which stay open to do
    /// at any time (the alphabet, for a learner who knows some letters or can read).
    static func states(lessonIDs: [String], completed: Set<String>, startIndex: Int = 0, openBefore: Int = 0) -> [String: LessonState] {
        var out: [String: LessonState] = [:]
        let firstOpen = lessonIDs.indices.first { $0 >= startIndex && !completed.contains(lessonIDs[$0]) }
        for (i, id) in lessonIDs.enumerated() {
            if completed.contains(id) { out[id] = .completed }
            else if i == firstOpen { out[id] = .current }
            else if i < openBefore { out[id] = .available }
            else if let f = firstOpen, i < f { out[id] = .available }
            else { out[id] = .locked }
        }
        return out
    }

    /// The lesson to continue with.
    static func next(lessonIDs: [String], completed: Set<String>, startIndex: Int = 0, openBefore: Int = 0) -> String? {
        let s = states(lessonIDs: lessonIDs, completed: completed, startIndex: startIndex, openBefore: openBefore)
        return lessonIDs.first { s[$0] == .current } ?? lessonIDs.first { s[$0] == .available }
    }
}

/// The learner's starting point, chosen during onboarding.
enum StartingLevel: String, CaseIterable, Identifiable {
    case beginner, someLetters, canRead

    var id: String { rawValue }
    var title: String {
        switch self {
        case .beginner: return tr("I'm brand new")
        case .someLetters: return tr("I know a few letters")
        case .canRead: return tr("I can read Georgian")
        }
    }
    var detail: String {
        switch self {
        case .beginner: return tr("Start with the alphabet, from the first letter.")
        case .someLetters: return tr("Start with the alphabet; every letter lesson is open to jump ahead.")
        case .canRead: return tr("Skip to everyday words. The alphabet stays open for revision.")
        }
    }
    var symbol: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .someLetters: return "textformat.abc"
        case .canRead: return "book.fill"
        }
    }
}
