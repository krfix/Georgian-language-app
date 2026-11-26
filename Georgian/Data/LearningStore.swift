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
    /// Words (and phrases) the learner knows now: shown instead of XP (KART #4).
    var wordsKnown: Int = 0
}

/// How well a letter or word is known, for badges in the vocabulary.
enum ItemStatus: String {
    case new = "New", learning = "Learning", learned = "Learned", difficult = "Difficult"

    /// The status in the learner's language.
    var title: String { tr(rawValue) }
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
    /// Phrasebook phrases the learner saved, marked or opened, by phrase id.
    private(set) var phraseRecords: [String: PhraseRecord] = [:]

    /// Writing progress failed (the iPhone out of space…): the screens tell the learner once,
    /// until a save works again. What wasn't written stays in memory and goes with the next save.
    var showSaveProblem = false
    @ObservationIgnored private var saveFailing = false

    /// Whether this build has the developer tools at all (KART #14). Only the Feather IPA
    /// (built with DEV_TOOLS) and Simulator runs (DEBUG) have them; TestFlight and the App Store
    /// don't, so there the section is hidden and switches saved by an older build do nothing.
    #if DEBUG || DEV_TOOLS
    static let devToolsAvailable = true
    #else
    static let devToolsAvailable = false
    #endif

    /// Developer mode (Profile › Developer, KART #8): one switch that shows two testing tools.
    /// Kept in UserDefaults, not with the progress.
    /// Someone who had "Open all lessons" on before it existed finds it on.
    var developerMode: Bool = UserDefaults.standard.object(forKey: "devMode") as? Bool
        ?? UserDefaults.standard.bool(forKey: "devUnlockAllLessons") {
        didSet { UserDefaults.standard.set(developerMode, forKey: "devMode") }
    }
    /// Tool 1: every lesson can be opened, whatever is finished.
    var devOpenAllLessons: Bool = UserDefaults.standard.bool(forKey: "devUnlockAllLessons") {
        didSet { UserDefaults.standard.set(devOpenAllLessons, forKey: "devUnlockAllLessons") }
    }
    /// Tool 2: a quick-pass button in lessons that counts the exercise as answered right.
    var devQuickPass: Bool = UserDefaults.standard.bool(forKey: "devQuickPass") {
        didSet { UserDefaults.standard.set(devQuickPass, forKey: "devQuickPass") }
    }
    /// The tools work only while developer mode is on, and only in builds that have them.
    var unlockAllLessons: Bool { Self.devToolsAvailable && developerMode && devOpenAllLessons }
    var quickPass: Bool { Self.devToolsAvailable && developerMode && devQuickPass }

    init(curriculum: Curriculum, context: ModelContext) {
        self.curriculum = curriculum
        self.context = context
        let existing: LearnerProfile?
        do {
            existing = try context.fetch(FetchDescriptor<LearnerProfile>()).first
        } catch {
            ProgressStore.log.error("Reading the profile failed: \(String(describing: error), privacy: .public)")
            existing = nil
        }
        if let existing {
            profile = existing
        } else {
            let p = LearnerProfile()
            context.insert(p)
            profile = p
        }
        save()
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
        let p = (try? context.fetch(FetchDescriptor<PhraseRecord>())) ?? []
        phraseRecords = Dictionary(p.map { ($0.phraseID, $0) }, uniquingKeysWith: { a, b in a.saved || !b.saved ? a : b })
    }

    var today: String { DayKey.of(now()) }
    var lessonIDs: [String] { curriculum.lessons.map(\.id) }
    private var alphabetCount: Int { curriculum.modules.first?.lessons.count ?? 0 }
    var startIndex: Int { profile.level == .canRead ? alphabetCount : 0 }

    /// The learner's stage (playful names, not exam levels). Someone who said "I can read"
    /// skipped the alphabet, so they start as a sign reader.
    var courseStage: CourseStage {
        var done = snapshot.modulesCompleted
        if profile.level == .canRead { done.insert("alphabet") }
        return CourseStage.current(modulesCompleted: done)
    }
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

    /// Answers given per day over the last `count` days, oldest first: the activity chart.
    func weeklyAnswers(_ count: Int = 7) -> [(day: String, answers: Int)] {
        DayKey.lastDays(count, endingOn: today).map { (day: $0, answers: days[$0]?.answers ?? 0) }
    }

    /// Achievements reached, counting only those the app still has.
    var unlockedAchievementCount: Int { Achievement.all.filter { achievementDates[$0.id] != nil }.count }

    /// Today's goal as a share, 0…1 (the goal is kept in XP inside; the screens don't show it).
    var goalProgressToday: Double { Double(xpToday) / Double(max(1, profile.dailyGoal)) }

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
        let reward = award(xp: xp, summary: summary) { d in
            d.lessons += 1
            if summary.isPerfect { d.perfectLessons += 1 }
        }
        refreshReminders()
        return reward
    }

    func finishReview(summary: SessionSummary, items: Int) -> LessonReward {
        let xp = XPRules.review(summary)
        context.insert(ReviewSessionRecord(date: now(), items: items, correct: summary.correctFirstTry, xp: xp))
        let reward = award(xp: xp, summary: summary) { _ in }
        refreshReminders()
        return reward
    }

    /// Plans the daily reminder again: the next two weeks, without today once the learner
    /// has practised (a lesson or review finished today, as the streak counts it). If
    /// notifications were switched off in the iPhone's Settings, the switch in Profile goes
    /// off too, so it never says "on" when nothing will come.
    func refreshReminders() {
        guard profile.remindersOn else { return }
        let (hour, minute, name, practised) = (profile.reminderHour, profile.reminderMinute, profile.name, xpToday > 0)
        Task {
            let allowed = await ReminderScheduler.refresh(hour: hour, minute: minute, name: name, practisedToday: practised)
            if !allowed { updateProfile { $0.remindersOn = false } }
        }
    }

    /// Turns the reminder on from Profile (asks for permission the first time).
    /// Returns false when notifications aren't allowed.
    func enableReminders() async -> Bool {
        let ok = await ReminderScheduler.enable(hour: profile.reminderHour, minute: profile.reminderMinute,
                                                name: profile.name, practisedToday: xpToday > 0)
        updateProfile { $0.remindersOn = ok }
        return ok
    }

    private func award(xp: Int, summary: SessionSummary, update: (DayRecord) -> Void) -> LessonReward {
        let before = snapshot
        let levelBefore = LearnerLevel.level(forXP: before.totalXP)
        let d = day(today)
        let xpBefore = d.xp
        d.xp += xp
        update(d)
        save()
        var challengeNow = false
        let today = self.today
        if let d = days[today], !d.challengeDone, challengeValue >= dailyChallenge.target {
            d.challengeDone = true
            d.xp += XPRules.challengeBonus
            challengeNow = true
            save()
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
                            newLevel: levelAfter > levelBefore ? levelAfter : nil, wordsKnown: after.wordsLearned)
    }

    /// Deletes all progress and starts again from the welcome screen.
    func resetAll() {
        do {
            try context.delete(model: LessonRecord.self)
            try context.delete(model: MasteryRecord.self)
            try context.delete(model: AnswerRecord.self)
            try context.delete(model: DayRecord.self)
            try context.delete(model: AchievementRecord.self)
            try context.delete(model: ReviewSessionRecord.self)
            try context.delete(model: PhraseRecord.self)
        } catch {
            ProgressStore.log.error("Deleting progress failed: \(String(describing: error), privacy: .public)")
        }
        let fresh = LearnerProfile()
        context.delete(profile)
        context.insert(fresh)
        profile = fresh
        save()
    }

    /// Writes what changed, then reads everything back. A failure is logged and shown once.
    private func save() {
        do {
            try context.save()
            saveFailing = false
        } catch {
            ProgressStore.log.error("Saving progress failed: \(String(describing: error), privacy: .public)")
            if !saveFailing {
                saveFailing = true
                showSaveProblem = true
            }
        }
        reload()
    }

    // MARK: Invented progress for screenshots and UI tests

    /// Fills the store with a made-up learner (Lena, two weeks in). Only used with the
    /// `-seedDemo` launch argument.
    func seedDemo() {
        let n = now()
        profile.name = "Lena"
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
        // The phrasebook: a few saved phrases (one list of her own), recently opened ones and
        // two in review.
        let saved = ["pb-ak-gamicheret-tu-sheidzleba", "pb-es-ra-ghirs", "pb-khortss-ar-vcham", "pb-ver-gavige",
                     "pb-aptiaki-sad-aris", "pb-tskheli-tsqali-ar-modis"]
        for (i, id) in saved.enumerated() where curriculum.phrasebook.phrase(id) != nil {
            let r = PhraseRecord(phraseID: id)
            r.saved = true
            r.savedAt = n.addingTimeInterval(-Double(i) * 7_200)
            r.list = id == "pb-tskheli-tsqali-ar-modis" ? "For the landlord" : ""
            r.learned = i == 3
            r.lastOpened = n.addingTimeInterval(-Double(i) * 1_800)
            r.opens = 3
            context.insert(r)
        }
        for (i, id) in ["pb-ramdeni-ikneba", "pb-erti-qava-tu-sheidzleba"].enumerated() where curriculum.phrasebook.phrase(id) != nil {
            let r = PhraseRecord(phraseID: id)
            r.lastOpened = n.addingTimeInterval(-Double(i + 1) * 900)
            r.opens = 1
            context.insert(r)
        }
        for id in ["pb-es-ra-ghirs", "pb-ver-gavige"] where curriculum.phrasebook.phrase(id) != nil {
            let m = MasteryRecord(itemID: id)
            m.due = n.addingTimeInterval(-600)
            m.lastSeen = n.addingTimeInterval(-86_400)
            context.insert(m)
        }
        for i in 0..<4 { context.insert(ReviewSessionRecord(date: n.addingTimeInterval(-Double(i) * 86_400), items: 10, correct: 8, xp: 13)) }
        save()
        for a in Achievement.all where a.isUnlocked(snapshot) {
            context.insert(AchievementRecord(achievementID: a.id, unlockedAt: n.addingTimeInterval(-86_400)))
        }
        save()
    }

    /// Every lesson done, for the screenshots of the finished vine (`-seedAll`).
    func completeAllLessons() {
        let n = now()
        for id in lessonIDs where !completedLessons.contains(id) {
            context.insert(LessonRecord(lessonID: id, completedAt: n.addingTimeInterval(-3_600), accuracy: 0.9, xp: 20, perfect: false))
        }
        save()
    }
}

// MARK: The phrasebook

extension LearningStore {
    var phrasebook: Phrasebook { curriculum.phrasebook }

    func isSaved(_ phraseID: String) -> Bool { phraseRecords[phraseID]?.saved ?? false }
    func isLearned(_ phraseID: String) -> Bool { phraseRecords[phraseID]?.learned ?? false }
    /// In spaced-repetition review (it has a schedule).
    func isPractising(_ phraseID: String) -> Bool { mastery[phraseID] != nil }
    func list(of phraseID: String) -> String { phraseRecords[phraseID]?.list ?? "" }

    /// The learner's phrasebook: saved phrases, newest first.
    var savedPhrases: [Phrase] {
        phraseRecords.values.filter(\.saved).sorted { $0.savedAt > $1.savedAt }.compactMap { phrasebook.phrase($0.phraseID) }
    }

    /// Phrases opened lately, newest first.
    var recentPhrases: [Phrase] {
        phraseRecords.values.filter { $0.opens > 0 }.sorted { $0.lastOpened > $1.lastOpened }
            .prefix(12).compactMap { phrasebook.phrase($0.phraseID) }
    }

    /// The names of the learner's own lists, in alphabetical order.
    var phraseLists: [String] {
        Array(Set(phraseRecords.values.filter { $0.saved && !$0.list.isEmpty }.map(\.list))).sorted()
    }

    var practisingPhraseCount: Int { mastery.keys.filter(Phrasebook.isPhraseID).count }

    private func phraseRecord(_ id: String) -> PhraseRecord {
        if let r = phraseRecords[id] { return r }
        let r = PhraseRecord(phraseID: id)
        context.insert(r)
        phraseRecords[id] = r
        return r
    }

    func toggleSaved(_ p: Phrase) { setSaved(p, !isSaved(p.id)) }

    func setSaved(_ p: Phrase, _ on: Bool) {
        let r = phraseRecord(p.id)
        r.saved = on
        if on { r.savedAt = now() } else { r.list = "" }
        save()
    }

    func setLearned(_ p: Phrase, _ on: Bool) {
        phraseRecord(p.id).learned = on
        save()
    }

    /// Puts a phrase in a list of the learner's own ("" for none), saving it if it wasn't.
    func move(_ p: Phrase, toList name: String) {
        let r = phraseRecord(p.id)
        if !r.saved { r.saved = true; r.savedAt = now() }
        r.list = name.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    /// Remembers that a phrase was opened, for "Recently used".
    func noteOpened(_ p: Phrase) {
        let r = phraseRecord(p.id)
        r.lastOpened = now()
        r.opens += 1
        save()
    }

    /// Saves a phrase and adds it to spaced-repetition review, due now. Already there: kept as it is.
    func practiseLater(_ p: Phrase) {
        let r = phraseRecord(p.id)
        if !r.saved { r.saved = true; r.savedAt = now() }
        if mastery[p.id] == nil {
            let m = MasteryRecord(itemID: p.id)
            m.due = now()
            m.lastSeen = Date.distantPast
            context.insert(m)
        }
        save()
    }

    /// Takes a phrase out of review (its schedule is deleted; it stays saved).
    func stopPractising(_ p: Phrase) {
        if let m = mastery[p.id] { context.delete(m) }
        save()
    }

    /// Phrases as review items.
    func studyItems(_ phrases: [Phrase]) -> [StudyItem] { phrases.map { .word(phrasebook.word(for: $0)) } }
}
