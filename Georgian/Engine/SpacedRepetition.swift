import Foundation

/// When each letter and word comes back for review: a version of the SM-2 method. Right
/// answers push the next review further away (1 day, 3 days, then longer and longer); a
/// mistake brings the item back within minutes and makes it come round more often.
struct ReviewState: Equatable {
    var ease: Double = 2.5
    /// Days until the next review.
    var interval: Int = 0
    /// Right answers in a row.
    var repetitions: Int = 0
    var due: Date
    var lapses: Int = 0

    init(ease: Double = 2.5, interval: Int = 0, repetitions: Int = 0, due: Date, lapses: Int = 0) {
        self.ease = ease
        self.interval = interval
        self.repetitions = repetitions
        self.due = due
        self.lapses = lapses
    }

    /// Known: answered right 4 times in a row, each on a different day (a same-day repeat
    /// doesn't count), so the last one came after more than a week away (KART #20; it was 2).
    var isLearned: Bool { repetitions >= 4 }
    /// Difficult: missed again and again.
    var isDifficult: Bool { lapses >= 2 || ease < 2.0 }
}

enum ReviewGrade: Equatable {
    case again, hard, good, easy

    init(_ verdict: Verdict) {
        switch verdict {
        case .correct: self = .good
        case .almost: self = .hard
        case .wrong: self = .again
        }
    }
}

enum SpacedRepetition {
    static let minimumEase = 1.3

    static func schedule(_ s: ReviewState, _ grade: ReviewGrade, now: Date, calendar: Calendar = .current) -> ReviewState {
        var n = s
        switch grade {
        case .again:
            n.repetitions = 0
            n.interval = 0
            n.lapses += 1
            n.ease = max(minimumEase, s.ease - 0.2)
            n.due = now.addingTimeInterval(10 * 60)
            return n
        case .hard:
            n.ease = max(minimumEase, s.ease - 0.15)
            n.interval = max(1, Int((Double(s.interval) * 1.2).rounded()))
        case .good:
            n.interval = s.repetitions == 0 ? 1 : s.repetitions == 1 ? 3 : max(s.interval + 1, Int((Double(s.interval) * s.ease).rounded()))
        case .easy:
            n.ease = s.ease + 0.15
            let good = s.repetitions == 0 ? 1 : s.repetitions == 1 ? 3 : Int((Double(s.interval) * s.ease).rounded())
            n.interval = max(s.interval + 1, Int((Double(good) * 1.3).rounded()))
        }
        n.repetitions = s.repetitions + 1
        let start = calendar.startOfDay(for: now)
        n.due = calendar.date(byAdding: .day, value: n.interval, to: start) ?? now.addingTimeInterval(Double(n.interval) * 86_400)
        return n
    }

    static func isDue(_ s: ReviewState, now: Date) -> Bool { s.due <= now }
}
