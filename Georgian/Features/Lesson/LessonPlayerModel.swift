import Foundation
import Observation

/// Runs one lesson or review on screen: the current exercise, the answer being made, the
/// feedback, and the reward at the end. All exercise kinds go through the same steps.
@MainActor @Observable
final class LessonPlayerModel {
    enum Phase: Equatable {
        /// Before a lesson, when words are due: warm up with them first? (KART #20)
        case warmUpOffer(Int)
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
    /// The answer just checked, for a mistake report made while its feedback shows.
    private var lastGiven: String?
    private let store: LearningStore
    private let audio: AudioService
    /// What the learner had met when the lesson started: the words new to them are the rest.
    private let metBefore: Set<String>
    /// The warm-up, ready in case it's wanted: due items and their exercises.
    private var warmUpItems: [StudyItem] = []
    private var warmUpExercises: [Exercise] = []
    private var lessonExercises: [Exercise] = []
    /// The warm-up items' schedules before it, to tell which became known.
    private var warmUpBefore: [String: ReviewState] = [:]
    private(set) var warmedUp = false
    /// Warm-up items one more right answer away from known.
    var warmUpAlmostKnown: Int { warmUpItems.filter { (store.mastery[$0.id]?.repetitions ?? 0) == 3 }.count }

    init(request: SessionRequest, store: LearningStore, audio: AudioService, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        self.request = request
        self.store = store
        self.audio = audio
        let builder = ExerciseBuilder(curriculum: store.curriculum, hasAudio: { [audio] text in
            MainActor.assumeIsolated { audio.canPlay(text) }
        })
        var rng = SeededGenerator(seed: seed)
        metBefore = store.seenOrPractised
        switch request.mode {
        case .lesson(let lesson):
            title = lesson.title
            let exercises = builder.exercises(for: lesson, using: &rng)
            let due = Array(store.dueItems.prefix(WordProgress.warmUpSize))
            let warm = due.isEmpty ? [] : builder.review(due, using: &rng).map { $0.renamed("warmup.\($0.id)") }
            lessonExercises = exercises
            warmUpItems = due
            warmUpExercises = warm
            session = LessonSession(exercises: exercises)
        case .review(let items, let t):
            title = t
            session = LessonSession(exercises: builder.review(Array(items.prefix(15)), using: &rng))
        case .dialogue(let lesson, _):
            title = lesson.title
            session = LessonSession(exercises: builder.exercises(for: lesson, using: &rng))
        }
        // Words due: offer a warm-up first, or start with it (Profile › Learning). The
        // screenshot run shows the offer only on its own screen ("warmup").
        if !warmUpItems.isEmpty {
            let screen = LaunchOptions.current.screen
            let mode: WarmUpMode = screen == "warmup" ? .ask : screen != nil ? .never : WarmUpMode.current
            switch mode {
            case .ask: phase = .warmUpOffer(warmUpItems.count)
            case .always: beginWarmUp()
            case .never: break
            }
        }
    }

    var current: Exercise? { session.current }

    /// Starts with the warm-up, then the lesson.
    func startWarmUp() {
        beginWarmUp()
        showed()
    }

    private func beginWarmUp() {
        warmUpBefore = Dictionary(warmUpItems.compactMap { i in store.mastery[i.id].map { (i.id, $0.state) } },
                                  uniquingKeysWith: { a, _ in a })
        warmedUp = true
        session = LessonSession(exercises: warmUpExercises + lessonExercises)
        phase = .answering
    }

    /// Skips the warm-up: straight to the lesson.
    func skipWarmUp() {
        phase = .answering
        showed()
    }

    var isReview: Bool { if case .review = request.mode { return true } else { return false } }
    var isDialogue: Bool { if case .dialogue = request.mode { return true } else { return false } }

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
        lastGiven = describe(given, in: ex)
        session.record(evaluation, given: describe(given, in: ex))
        store.record(ex, evaluation, given: describe(given, in: ex), inReview: isReview || isDialogue || ex.isWarmUp)
        if evaluation.verdict.countsAsCorrect {
            combo += 1
            Haptics.success()
        } else {
            combo = 0
            Haptics.error()
        }
        phase = .feedback(evaluation)
        audio.autoSay(AutoSpeech.onCheck(ex, given: given, correct: evaluation.verdict.countsAsCorrect))
    }

    /// The exercise on screen has just appeared: say its Georgian if that's allowed.
    func showed() {
        guard case .answering = phase, let ex = current else { return }
        audio.autoSay(AutoSpeech.onShow(ex))
    }

    /// The learner changed their answer: say the Georgian they picked.
    func picked(from old: Answer?, to new: Answer?) {
        guard case .answering = phase, let ex = current else { return }
        audio.autoSay(AutoSpeech.onPick(ex, from: old, to: new))
    }

    /// Moves on: past a teaching card, or past the feedback.
    func next() {
        session.advance()
        pending = nil
        if session.isFinished {
            finish()
        } else {
            phase = .answering
            showed()
        }
    }

    private func finish() {
        let reward: LessonReward
        switch request.mode {
        case .lesson(let lesson):
            var r = store.finishLesson(lesson, summary: session.summary)
            r.newWords = WordProgress.newWords(in: lesson, before: metBefore).compactMap(store.curriculum.word)
            if warmedUp {
                r.warmUpCount = warmUpItems.count
                let after = Dictionary(warmUpItems.compactMap { i in store.mastery[i.id].map { (i.id, $0.state) } },
                                       uniquingKeysWith: { a, _ in a })
                let known = Set(WordProgress.newlyKnown(warmUpItems.map(\.id), before: warmUpBefore, after: after))
                r.warmUpKnown = warmUpItems.filter { known.contains($0.id) }
            }
            reward = r
        case .review(let items, _): reward = store.finishReview(summary: session.summary, items: min(items.count, 15))
        case .dialogue: reward = store.finishReview(summary: session.summary, items: session.gradedTotal)
        }
        Haptics.celebrate()
        phase = .finished(reward)
    }

    /// What "Report a mistake" sends: the exercise on screen, and the answer and the right
    /// one while the feedback shows.
    var reportSubject: ReportSubject {
        let ref: String
        switch request.mode {
        case .lesson(let l): ref = l.id
        case .dialogue(let l, _): ref = l.id
        case .review: ref = "review"
        }
        guard let ex = current else {
            return ReportSubject(title: tr("the lesson {0}", title), lines: [tr("Lesson: {0}", title)], id: ref)
        }
        var given: String?
        var shown: String?
        if case .feedback(let e) = phase {
            given = lastGiven
            shown = e.correctAnswer
        }
        return ReportSubject(title: tr("the lesson {0}", title),
                             lines: ex.reportLines(lessonTitle: title, given: given, shownAnswer: shown), id: "\(ref)/\(ex.id)")
    }

    /// Developer quick pass (Profile › Developer): the exercise on screen counts as answered
    /// right, first time, and the lesson moves straight on; after feedback it just moves on.
    func passCorrect() {
        if case .feedback = phase { next(); return }
        guard case .answering = phase, let ex = current else { return }
        if ex.isGraded {
            let right = Evaluation(verdict: .correct, correctAnswer: "", explanation: nil)
            session.record(right, given: "")
            store.record(ex, right, given: tr("quick pass"), inReview: isReview || isDialogue || ex.isWarmUp)
            combo += 1
        }
        next()
    }

    /// Developer quick pass, held: every exercise left counts as right, and the lesson ends.
    func passAll() {
        if case .warmUpOffer = phase { skipWarmUp() }
        var guardCount = 0
        while current != nil, guardCount < 500 {
            if case .finished = phase { break }
            passCorrect()
            guardCount += 1
        }
    }

    /// Jumps to the first exercise of a kind, without answering (screenshots only).
    func skip(toKind kind: String) {
        while let ex = session.current, ex.kind.rawValue != kind { session.advance() }
        if session.isFinished { session = LessonSession(exercises: []) }
    }

    /// A reward to show straight away (the screenshot of the completion screen).
    func showSampleReward() {
        var r = LessonReward(xp: 27, accuracy: 0.92, isPerfect: false, streak: store.streak, xpToday: store.xpToday,
                             dailyGoal: store.profile.dailyGoal, goalReachedNow: true, challengeCompletedNow: false,
                             achievements: Array(Achievement.all.prefix(1)), newLevel: nil,
                             wordsKnown: store.snapshot.wordsLearned)
        if case .lesson(let lesson) = request.mode {
            r.newWords = (lesson.seen ?? []).compactMap(store.curriculum.word)
            r.warmUpCount = 4
            r.warmUpKnown = Array(store.dueItems.prefix(1))
        }
        phase = .finished(r)
    }

    private func describe(_ a: Answer, in ex: Exercise) -> String {
        switch (a, ex.content) {
        case (.choice(let i), .choice(let c)): return c.options.first { $0.id == i }?.text ?? ""
        case (.choice(let i), .dialogue(let d)): return i < d.options.count ? d.options[i] : ""
        case (.text(let s), _): return s
        case (.tiles(let t), .tiles(let tiles)): return t.joined(separator: tiles.joiner)
        case (.matched(let m), _): return m == 0 ? tr("all matched") : tr("{0} wrong pairs", m)
        case (.recalled(let k), _): return k ? tr("remembered") : tr("didn't remember")
        default: return ""
        }
    }
}
