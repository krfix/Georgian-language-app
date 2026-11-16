import Foundation

/// One run through a lesson or review: which exercise is on screen, what was answered, and
/// the retry queue. A graded exercise answered wrong comes back once at the end.
struct LessonSession {
    private(set) var queue: [Exercise]
    private(set) var index = 0
    /// First-try results of graded exercises, by exercise id.
    private(set) var firstTry: [String: Bool] = [:]
    private(set) var mistakes: [Mistake] = []
    private(set) var answered = 0

    struct Mistake: Hashable {
        let exercise: Exercise
        let given: String
        let expected: String
    }

    init(exercises: [Exercise]) {
        queue = exercises
    }

    var current: Exercise? { index < queue.count ? queue[index] : nil }
    var isFinished: Bool { index >= queue.count }

    /// Graded exercises in the lesson as it started (retries not counted).
    var gradedTotal: Int { queue.filter { $0.isGraded && !$0.id.hasSuffix("+") }.count }

    /// How far through: every exercise done counts, retries add to the total.
    var progress: Double {
        guard !queue.isEmpty else { return 1 }
        return Double(index) / Double(queue.count)
    }

    /// Records an answer to the current exercise. Teaching cards just pass.
    mutating func record(_ evaluation: Evaluation, given: String) {
        guard let ex = current, ex.isGraded else { return }
        answered += 1
        let ok = evaluation.verdict.countsAsCorrect
        let baseID = ex.id.hasSuffix("+") ? String(ex.id.dropLast()) : ex.id
        if firstTry[baseID] == nil { firstTry[baseID] = ok }
        if !ok {
            mistakes.append(Mistake(exercise: ex, given: given, expected: evaluation.correctAnswer))
            if !ex.id.hasSuffix("+") { queue.append(ex.retry()) }
        }
    }

    mutating func advance() {
        if index < queue.count { index += 1 }
    }

    var correctFirstTry: Int { firstTry.values.filter { $0 }.count }

    var summary: SessionSummary {
        SessionSummary(graded: firstTry.count, correctFirstTry: correctFirstTry, mistakes: mistakes.count)
    }
}

struct SessionSummary: Equatable {
    let graded: Int
    let correctFirstTry: Int
    let mistakes: Int

    var accuracy: Double { graded == 0 ? 1 : Double(correctFirstTry) / Double(graded) }
    var isPerfect: Bool { graded > 0 && correctFirstTry == graded }
}
