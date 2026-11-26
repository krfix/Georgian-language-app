import Foundation

/// How far along a word is (KART #20): not seen yet → seen (it was on screen in a finished
/// lesson) → practising (it has a review schedule) → known (right 4 times in a row, on
/// different days: `ReviewState.isLearned`). Nothing new is saved for "seen": it is worked out
/// from the finished lessons and the words each lesson shows (`Lesson.seen`, made by the
/// content build), so it also counts lessons finished before this existed.
enum WordProgress {
    /// Every word in the finished lessons, with the first of those lessons in course order.
    static func seen(lessons: [Lesson], completed: Set<String>) -> [String: String] {
        var out: [String: String] = [:]
        for l in lessons where completed.contains(l.id) {
            for id in l.seen ?? [] where out[id] == nil { out[id] = l.id }
        }
        return out
    }

    /// Every word the course shows, with the first lesson that shows it.
    static func firstLesson(lessons: [Lesson]) -> [String: String] {
        seen(lessons: lessons, completed: Set(lessons.map(\.id)))
    }

    /// The words a lesson shows that the learner hadn't met before it: not in another
    /// finished lesson and not practised. `before` is what was seen or practised when the
    /// lesson started.
    static func newWords(in lesson: Lesson, before: Set<String>) -> [String] {
        (lesson.seen ?? []).filter { !before.contains($0) }
    }

    /// The items from a warm-up that are known now and weren't before it.
    static func newlyKnown(_ ids: [String], before: [String: ReviewState], after: [String: ReviewState]) -> [String] {
        ids.filter { (after[$0]?.isLearned ?? false) && !(before[$0]?.isLearned ?? false) }
    }

    /// How many items a warm-up brings back at most.
    static let warmUpSize = 4
}

/// Whether a lesson starts with a few due words first (Profile › Learning).
enum WarmUpMode: String, CaseIterable, Identifiable {
    case ask, always, never
    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask: return tr("Ask")
        case .always: return tr("Always")
        case .never: return tr("Never")
        }
    }

    /// Kept in UserDefaults with the other settings, not with the progress.
    static var current: WarmUpMode {
        get { UserDefaults.standard.string(forKey: "warmUp").flatMap(WarmUpMode.init(rawValue:)) ?? .ask }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "warmUp") }
    }
}
