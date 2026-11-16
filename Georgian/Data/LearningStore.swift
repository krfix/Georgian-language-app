import Foundation
import Observation
import SwiftData

/// What a finished lesson or review earned, for the completion screen.
struct LessonReward: Equatable {
    var xp: Int
    var accuracy: Double
    var isPerfect: Bool
    var streak: Int
    var xpToday: Int
    var dailyGoal: Int
    var goalReachedNow: Bool
    var challengeCompletedNow: Bool
    var achievements: [Achievement]
    var newLevel: Int?
}

/// How well a letter or word is known, for badges in the vocabulary.
enum ItemStatus: String {
    case new = "New", learning = "Learning", learned = "Learned", difficult = "Difficult"
}

/// The app's saved progress and everything worked out from it. Views read from here and
/// call its methods; it writes through SwiftData and keeps a fresh copy of what it read.
@MainActor @Observable
final class LearningStore {
    let curriculum: Curriculum
    private let context: ModelContext
    @ObservationIgnored var now: () -> Date = Date.init

    private(set) var profile: LearnerProfile
    private(set) var lessonRecords: [LessonRecord] = []
    private(set) var completedLessons: Set<String> = []
    private(set) var mastery: [String: MasteryRecord] = [:]
    private(set) var days: [String: DayRecord] = [:]
    private(set) var achievementDates: [String: Date] = [:]
    private(set) var reviewSessionCount = 0
    private(set) var recentMistakes: [AnswerRecord] = []
    private(set) var answerTotals = (all: 0, correct: 0)

    /// Developer switch (Profile › Developer): every lesson open, for testing. Kept in
    /// UserDefaults, not with the progress.
    var unlockAllLessons: Bool = UserDefaults.standard.bool(forKey: "devUnlockAllLessons") {
        didSet { UserDefaults.standard.set(unlockAllLessons, forKey: "devUnlockAllLessons") }
    }

    init(curriculum: Curriculum, context: ModelContext) {
        self.curriculum = curriculum
        self.context = context
        let existing = (try? context.fetch(FetchDescriptor<LearnerProfile>()))?.first
        if let existing {
            profile = existing
        } else {
            let p = LearnerProfile()
            context.insert(p)
            try? context.save()
            profile = p
        }
        reload()
    }

    // MARK: Reading

    func reload() {
        lessonRecords = (try? context.fetch(FetchDescriptor<LessonRecord>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)]))) ?? []
        completedLessons = Set(lessonRecords.map(\.lessonID))
        let m = (try? context.fetch(FetchDescriptor<MasteryRecord>())) ?? []
        mastery = Dictionary(m.map { ($0.itemID, $0) }, uniquingKeysWith: { a, _ in a })
        let d = (try? context.fetch(FetchDescriptor<DayRecord>())) ?? []
        days = Dictionary(d.map { ($0.day, $0) }, uniquingKeysWith: { a, b in a.xp >= b.xp ? a : b })
        let a = (try? context.fetch(FetchDescriptor<AchievementRecord>())) ?? []
        achievementDates = Dictionary(a.map { ($0.achievementID, $0.unlockedAt) }, uniquingKeysWith: { x, _ in x })
        reviewSessionCount = (try? context.fetchCount(FetchDescriptor<ReviewSessionRecord>())) ?? 0
        var wrong = FetchDescriptor<AnswerRecord>(predicate: #Predicate<AnswerRecord> { !$0.correct }, sortBy: [SortDescriptor(\.date, order: .reverse)])
        wrong.fetchLimit = 30
        recentMistakes = (try? context.fetch(wrong)) ?? []
        let all = (try? context.fetchCount(FetchDescriptor<AnswerRecord>())) ?? 0
        let right = (try? context.fetchCount(FetchDescriptor<AnswerRecord>(predicate: #Predicate<AnswerRecord> { $0.correct }))) ?? 0
        answerTotals = (all, right)
    }

    var today: String { DayKey.of(now()) }
    var lessonIDs: [String] { curriculum.lessons.map(\.id) }
    private var alphabetCount: Int { curriculum.modules.first?.lessons.count ?? 0 }
    var startIndex: Int { profile.level == .canRead ? alphabetCount : 0 }
    var openBefore: Int { profile.level == .beginner ? 0 : alphabetCount }

    var lessonStates: [String: LessonState] {
        let states = CourseProgress.states(lessonIDs: lessonIDs, completed: completedLessons, startIndex: startIndex, openBefore: openBefore)
        guard unlockAllLessons else { return states }
        return states.mapValues { $0 == .locked ? .available : $0 }
    }

    func state(of lesson: Lesson) -> LessonState { lessonStates[lesson.id] ?? .locked }

    var nextLesson: Lesson? {
        CourseProgress.next(lessonIDs: lessonIDs, completed: completedLessons, startIndex: startIndex, openBefore: openBefore)
            .flatMap(curriculum.lesson)
    }

    func completedCount(in module: CourseModule) -> Int {
        module.lessons.filter { completedLessons.contains($0.id) }.count
    }

    var totalXP: Int { days.values.reduce(0) { $0 + $1.xp } }
    var xpToday: Int { days[today]?.xp ?? 0 }
    var streak: Int { snapshot.streak }

    var snapshot: ProgressSnapshot {
        var s = ProgressSnapshot()
        s.totalXP = totalXP
        s.xpByDay = days.mapValues(\.xp)
        s.lessonsCompleted = completedLessons
        s.perfectLessons = lessonRecords.filter(\.perfect).count
        s.wordsLearned = mastery.values.filter { !$0.itemID.hasPrefix("letter-") && $0.state.isLearned }.count
        s.lettersLearned = mastery.values.filter { $0.itemID.hasPrefix("letter-") && $0.state.isLearned }.count
        s.reviewSessions = reviewSessionCount
        s.dailyGoal = profile.dailyGoal
        s.modulesCompleted = Set(curriculum.modules.filter { m in m.lessons.allSatisfy { completedLessons.contains($0.id) } }.map(\.id))
        s.today = today
        return s
    }

    var accuracy: Double {
        answerTotals.all == 0 ? 0 : Double(answerTotals.correct) / Double(answerTotals.all)
    }

    func status(of itemID: String) -> ItemStatus {
        guard let m = mastery[itemID] else { return .new }
        if m.state.isDifficult { return .difficult }
        return m.state.isLearned ? .learned : .learning
    }

    /// Letters and words due for review, the most overdue first.
    var dueItems: [StudyItem] {
        let n = now()
        return mastery.values.filter { $0.due <= n }.sorted { $0.due < $1.due }.compactMap { curriculum.item($0.itemID) }
    }

    /// Items missed again and again, the hardest first.
    var difficultItems: [StudyItem] {
        mastery.values.filter { $0.state.isDifficult }
            .sorted { ($0.lapses, -$0.ease) > ($1.lapses, -$1.ease) }
            .compactMap { curriculum.item($0.itemID) }
    }

    /// The weakest items, for practice when nothing is due.
    var weakestItems: [StudyItem] {
        mastery.values.sorted { ($0.ease, -Double($0.wrongCount)) < ($1.ease, -Double($1.wrongCount)) }
            .compactMap { curriculum.item($0.itemID) }
    }

    var dailyChallenge: DailyChallenge { DailyChallenge.of(day: today, dailyGoal: profile.dailyGoal) }

    var challengeValue: Int {
        let d = days[today]
        return dailyChallenge.value(xp: d?.xp ?? 0, perfectLessons: d?.perfectLessons ?? 0, reviewed: d?.reviewed ?? 0, lessons: d?.lessons ?? 0)
    }

    var challengeDone: Bool { days[today]?.challengeDone ?? false }

    /// XP per day over the last `count` days, oldest first.
    func weeklyXP(_ count: Int = 7) -> [(day: String, xp: Int)] {
        DayKey.lastDays(count, endingOn: today).map { (day: $0, xp: days[$0]?.xp ?? 0) }
    }

    // MARK: Writing

    func completeOnboarding(name: String, level: StartingLevel, goal: DailyGoal) {
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.levelRaw = level.rawValue
        profile.dailyGoal = goal.rawValue
        profile.onboardingDone = true
        save()
    }

    func updateProfile(_ change: (LearnerProfile) -> Void) {
        change(profile)
        save()
    }

    /// Saves one answer: its review schedule, the answer log and today's counts.
    func record(_ exercise: Exercise, _ evaluation: Evaluation, given: String, inReview: Bool) {
        guard exercise.isGraded else { return }
        let n = now()
        let isRetry = exercise.id.hasSuffix("+")
        let ok = evaluation.verdict.countsAsCorrect
        var items: [String] = []
        if let id = exercise.itemID { items = [id] }
        if case .matching(let pairs) = exercise.content, ok { items = pairs.map(\.id) }
        if !isRetry {
            for id in items { schedule(id, ReviewGrade(evaluation.verdict), at: n) }
        }
        let prompt: String
        switch exercise.content {
        case .choice(let c): prompt = c.prompt
        case .typing(let t): prompt = t.prompt
        case .tiles(let t): prompt = t.prompt
        case .flashcard(let f): prompt = f.front
        case .dialogue(let d): prompt = d.history.last?.ka ?? d.partner
        default: prompt = exercise.instruction
        }
        context.insert(AnswerRecord(itemID: exercise.itemID ?? "", exerciseKind: exercise.kind.rawValue, correct: ok,
                                    given: given, expected: evaluation.correctAnswer, prompt: prompt, date: n))
        let d = day(today)
        d.answers += 1
        if ok { d.correctAnswers += 1 }
        if inReview { d.reviewed += 1 }
        save()
    }

    private func schedule(_ itemID: String, _ grade: ReviewGrade, at n: Date) {
        let m: MasteryRecord
        if let existing = mastery[itemID] {
            m = existing
        } else {
            m = MasteryRecord(itemID: itemID)
            m.due = n
            context.insert(m)
            mastery[itemID] = m
        }
        // Right again on the same day doesn't move it further: spacing needs days in between.
        let sameDay = DayKey.of(m.lastSeen) == DayKey.of(n) && m.repetitions > 0
        if grade == .again {
            m.state = SpacedRepetition.schedule(m.state, .again, now: n)
            m.wrongCount += 1
        } else {
            if !sameDay { m.state = SpacedRepetition.schedule(m.state, grade, now: n) }
            m.correctCount += 1
        }
        m.lastSeen = n
    }

    private func day(_ key: String) -> DayRecord {
        if let d = days[key] { return d }
        let d = DayRecord(day: key)
        context.insert(d)
        days[key] = d
        return d
    }

    func finishLesson(_ lesson: Lesson, summary: SessionSummary) -> LessonReward {
        let xp = XPRules.lesson(summary)
        context.insert(LessonRecord(lessonID: lesson.id, completedAt: now(), accuracy: summary.accuracy, xp: xp, perfect: summary.isPerfect))
        return award(xp: xp, summary: summary) { d in
            d.lessons += 1
            if summary.isPerfect { d.perfectLessons += 1 }
        }
    }

    func finishReview(summary: SessionSummary, items: Int) -> LessonReward {
        let xp = XPRules.review(summary)
        context.insert(ReviewSessionRecord(date: now(), items: items, correct: summary.correctFirstTry, xp: xp))
        return award(xp: xp, summary: summary) { _ in }
    }

    private func award(xp: Int, summary: SessionSummary, update: (DayRecord) -> Void) -> LessonReward {
        let before = snapshot
        let levelBefore = LearnerLevel.level(forXP: before.totalXP)
        let d = day(today)
        let xpBefore = d.xp
        d.xp += xp
        update(d)
        try? context.save()
        reload()
        var challengeNow = false
        let today = self.today
        if let d = days[today], !d.challengeDone, challengeValue >= dailyChallenge.target {
            d.challengeDone = true
            d.xp += XPRules.challengeBonus
            challengeNow = true
            try? context.save()
            reload()
        }
        let after = snapshot
        let unlocked = Achievement.newlyUnlocked(before: before, after: after, alreadyRecorded: Set(achievementDates.keys))
        for a in unlocked { context.insert(AchievementRecord(achievementID: a.id, unlockedAt: now())) }
        save()
        let levelAfter = LearnerLevel.level(forXP: after.totalXP)
        return LessonReward(xp: xp + (challengeNow ? XPRules.challengeBonus : 0), accuracy: summary.accuracy,
                            isPerfect: summary.isPerfect, streak: after.streak, xpToday: after.xpToday,
                            dailyGoal: profile.dailyGoal,
                            goalReachedNow: xpBefore < profile.dailyGoal && after.xpToday >= profile.dailyGoal,
                            challengeCompletedNow: challengeNow, achievements: unlocked,
                            newLevel: levelAfter > levelBefore ? levelAfter : nil)
    }

    /// Deletes all progress and starts again from the welcome screen.
    func resetAll() {
        try? context.delete(model: LessonRecord.self)
        try? context.delete(model: MasteryRecord.self)
        try? context.delete(model: AnswerRecord.self)
        try? context.delete(model: DayRecord.self)
        try? context.delete(model: AchievementRecord.self)
        try? context.delete(model: ReviewSessionRecord.self)
        let fresh = LearnerProfile()
        context.delete(profile)
        context.insert(fresh)
        profile = fresh
        save()
    }

    private func save() {
        try? context.save()
        reload()
    }

    // MARK: Invented progress for screenshots and UI tests

    /// Fills the store with a made-up learner (Ana, two weeks in). Only used with the
    /// `-seedDemo` launch argument.
    func seedDemo() {
        let n = now()
        profile.name = "Ana"
        profile.onboardingDone = true
        profile.dailyGoal = 20
        let done = ["a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9", "a10", "v1", "v2", "v3"]
        for (i, id) in done.enumerated() {
            context.insert(LessonRecord(lessonID: id, completedAt: n.addingTimeInterval(Double(i - done.count) * 86_400),
                                        accuracy: [0.8, 0.9, 1, 0.75, 0.95][i % 5], xp: 22, perfect: i % 4 == 2))
        }
        for (i, l) in curriculum.letters.enumerated() {
            let m = MasteryRecord(itemID: l.itemID)
            m.repetitions = i % 7 == 0 ? 1 : 3
            m.interval = m.repetitions == 1 ? 1 : 8
            m.due = n.addingTimeInterval(i % 9 == 0 ? -3_600 : Double(m.interval) * 86_400)
            m.lapses = ["ღ", "ყ", "წ"].contains(l.char) ? 2 : 0
            m.ease = m.lapses > 0 ? 1.9 : 2.5
            m.correctCount = 5
            m.wrongCount = m.lapses
            m.lastSeen = n.addingTimeInterval(-86_400)
            context.insert(m)
        }
        let words = ["v1", "v2", "v3"].compactMap(curriculum.lesson).flatMap { curriculum.words(in: $0) }
        for (i, w) in words.enumerated() {
            let m = MasteryRecord(itemID: w.id)
            m.repetitions = i % 3 == 0 ? 1 : 2
            m.interval = m.repetitions == 1 ? 1 : 3
            m.due = n.addingTimeInterval(i % 3 == 0 ? -7_200 : 2 * 86_400)
            m.lapses = i % 5 == 1 ? 2 : 0
            m.ease = m.lapses > 0 ? 1.8 : 2.5
            m.correctCount = 3
            m.wrongCount = m.lapses
            m.lastSeen = n.addingTimeInterval(-86_400)
            context.insert(m)
            if m.lapses > 0 {
                context.insert(AnswerRecord(itemID: w.id, exerciseKind: ExerciseKind.multipleChoice.rawValue, correct: false,
                                            given: "goodbye", expected: w.en, prompt: w.ka, date: n.addingTimeInterval(-Double(i) * 3_600)))
            }
            context.insert(AnswerRecord(itemID: w.id, exerciseKind: ExerciseKind.multipleChoice.rawValue, correct: true,
                                        given: w.en, expected: w.en, prompt: w.ka, date: n.addingTimeInterval(-Double(i) * 3_000)))
        }
        let xps = [14, 25, 20, 31, 0, 22, 26, 18, 40, 21, 24, 12]
        for (i, xp) in xps.enumerated() where xp > 0 {
            let d = DayRecord(day: DayKey.adding(-(xps.count - 1 - i), to: today))
            d.xp = xp
            d.lessons = xp / 15
            d.answers = xp
            d.correctAnswers = xp - 2
            d.challengeDone = i % 3 == 0
            context.insert(d)
        }
        for i in 0..<4 { context.insert(ReviewSessionRecord(date: n.addingTimeInterval(-Double(i) * 86_400), items: 10, correct: 8, xp: 13)) }
        try? context.save()
        reload()
        for a in Achievement.all where a.isUnlocked(snapshot) {
            context.insert(AchievementRecord(achievementID: a.id, unlockedAt: n.addingTimeInterval(-86_400)))
        }
        save()
    }
}
