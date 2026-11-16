import Foundation
import Observation

/// Runs one lesson or review on screen: the current exercise, the answer being made, the
/// feedback, and the reward at the end. All exercise kinds go through the same steps.
@MainActor @Observable
final class LessonPlayerModel {
    enum Phase: Equatable {
        case answering
        case feedback(Evaluation)
        case finished(LessonReward)
    }

    let request: SessionRequest
    let title: String
    private(set) var session: LessonSession
    private(set) var phase: Phase = .answering
    /// The answer being put together; Check is enabled once there is one.
    var pending: Answer?
    /// Right answers in a row, for the little flame over the progress bar.
    private(set) var combo = 0
    private let store: LearningStore

    init(request: SessionRequest, store: LearningStore, audio: AudioService, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        self.request = request
        self.store = store
        let builder = ExerciseBuilder(curriculum: store.curriculum, hasAudio: { [audio] text in
            MainActor.assumeIsolated { audio.canPlay(text) }
        })
        var rng = SeededGenerator(seed: seed)
        switch request.mode {
        case .lesson(let lesson):
            title = lesson.title
            session = LessonSession(exercises: builder.exercises(for: lesson, using: &rng))
        case .review(let items, let t):
            title = t
            session = LessonSession(exercises: builder.review(Array(items.prefix(15)), using: &rng))
        }
    }

    var current: Exercise? { session.current }
    var isReview: Bool { if case .review = request.mode { return true } else { return false } }

    var canCheck: Bool {
        guard case .answering = phase, let pending else { return false }
        if case .text(let s) = pending { return !s.trimmingCharacters(in: .whitespaces).isEmpty }
        if case .tiles(let t) = pending { return !t.isEmpty }
        return true
    }

    /// Checks the pending answer (or the one given) and shows the feedback.
    func check(_ answer: Answer? = nil) {
        guard case .answering = phase, let ex = current, let given = answer ?? pending else { return }
        let evaluation = AnswerEvaluator.evaluate(ex, given)
        session.record(evaluation, given: describe(given, in: ex))
        store.record(ex, evaluation, given: describe(given, in: ex), inReview: isReview)
        if evaluation.verdict.countsAsCorrect {
            combo += 1
            Haptics.success()
        } else {
            combo = 0
            Haptics.error()
        }
        phase = .feedback(evaluation)
    }

    /// Moves on: past a teaching card, or past the feedback.
    func next() {
        session.advance()
        pending = nil
        if session.isFinished {
            finish()
        } else {
            phase = .answering
        }
    }

    private func finish() {
        let reward: LessonReward
        switch request.mode {
        case .lesson(let lesson): reward = store.finishLesson(lesson, summary: session.summary)
        case .review(let items, _): reward = store.finishReview(summary: session.summary, items: min(items.count, 15))
        }
        Haptics.celebrate()
        phase = .finished(reward)
    }

    /// A reward to show straight away (the screenshot of the completion screen).
    func showSampleReward() {
        phase = .finished(LessonReward(xp: 27, accuracy: 0.92, isPerfect: false, streak: store.streak, xpToday: store.xpToday,
                                       dailyGoal: store.profile.dailyGoal, goalReachedNow: true, challengeCompletedNow: false,
                                       achievements: Array(Achievement.all.prefix(1)), newLevel: nil))
    }

    private func describe(_ a: Answer, in ex: Exercise) -> String {
        switch (a, ex.content) {
        case (.choice(let i), .choice(let c)): return c.options.first { $0.id == i }?.text ?? ""
        case (.choice(let i), .dialogue(let d)): return i < d.options.count ? d.options[i] : ""
        case (.text(let s), _): return s
        case (.tiles(let t), .tiles(let tiles)): return t.joined(separator: tiles.joiner)
        case (.matched(let m), _): return m == 0 ? "all matched" : "\(m) wrong pairs"
        case (.recalled(let k), _): return k ? "remembered" : "didn't remember"
        default: return ""
        }
    }
}
