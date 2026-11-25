import Foundation
import SwiftData

// Opens a store written by an old version (WriteOld) with the CURRENT app's code
// (Georgian/Data/Models.swift and ProgressStore.swift) and checks all its progress is there.
// Usage: check-new <store path> <v1|v2>
// Also checks the store opens a second time, takes new progress, and can be kept aside.

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let from = CommandLine.arguments[2]
let start = Date(timeIntervalSince1970: 1_790_000_000)
var failures = 0
var passes = 0

func check<T: Equatable>(_ label: String, _ got: T, _ want: T) {
    if got == want {
        passes += 1
    } else {
        failures += 1
        print("FAIL \(from): \(label): got \(got), want \(want)")
    }
}

func fetch<M: PersistentModel>(_ type: M.Type, _ context: ModelContext) -> [M] {
    do {
        return try context.fetch(FetchDescriptor<M>())
    } catch {
        check("reading \(M.self)", "\(error)", "no error")
        return []
    }
}

do {
    let opened = try ProgressStore.open(at: url)
    check("opened with the migration plan (not the fallback)", opened.usedFallback, false)
    let context = ModelContext(opened.container)

    let profiles = fetch(LearnerProfile.self, context)
    check("profiles", profiles.count, 1)
    if let p = profiles.first {
        check("name", p.name, "Test learner")
        check("level", p.level, .someLetters)
        check("daily goal", p.dailyGoal, 30)
        check("onboarding done", p.onboardingDone, true)
        check("appearance", p.appearance, "dark")
        check("reminder", "\(p.remindersOn) \(p.reminderHour)", "true 8")
    }

    let lessons = fetch(LessonRecord.self, context)
    check("lessons", Set(lessons.map(\.lessonID)), ["a1", "a2", "a3"])
    check("perfect lessons", lessons.filter(\.perfect).map(\.lessonID), ["a2"])

    let mastery = Dictionary(fetch(MasteryRecord.self, context).map { ($0.itemID, $0) }, uniquingKeysWith: { a, _ in a })
    check("review items", Set(mastery.keys), ["letter-ა", "w-gamarjoba", "pb-es-ra-ghirs"])
    if let m = mastery["w-gamarjoba"] {
        check("schedule (interval, repetitions, lapses)", "\(m.interval) \(m.repetitions) \(m.lapses)", "4 2 1")
        check("due date", m.due, start.addingTimeInterval(4 * 86_400))
        check("ease", (m.ease * 10).rounded(), 23)
        check("review state", m.state.repetitions, 2)
    }

    let answers = fetch(AnswerRecord.self, context)
    check("answers", answers.count, 2)
    check("wrong answers", answers.filter { !$0.correct }.map(\.given), ["goodbye"])

    let days = fetch(DayRecord.self, context)
    check("days", days.map(\.day), ["2026-09-21"])
    check("day's counts", days.first.map { "\($0.xp) \($0.lessons) \($0.answers) \($0.correctAnswers) \($0.challengeDone)" },
          "42 2 17 15 true")
    check("achievements", fetch(AchievementRecord.self, context).map(\.achievementID), ["first-lesson"])
    check("review sessions", fetch(ReviewSessionRecord.self, context).map(\.items), [10])

    let phrases = fetch(PhraseRecord.self, context)
    if from == "v1" {
        check("phrases (none before version 2)", phrases.count, 0)
    } else {
        check("phrases", phrases.map(\.phraseID), ["pb-es-ra-ghirs"])
        check("phrase record", phrases.first.map { "\($0.saved) \($0.list) \($0.learned) \($0.opens)" }, "true For the bazaar true 4")
    }

    // New progress goes in, and the store opens again with it.
    context.insert(PhraseRecord(phraseID: "pb-new"))
    context.insert(LessonRecord(lessonID: "a4", completedAt: start, accuracy: 1, xp: 20, perfect: true))
    try context.save()
} catch {
    check("opening the old store", "\(error)", "no error")
}

do {
    let again = try ProgressStore.open(at: url)
    check("opened again with the plan", again.usedFallback, false)
    let context = ModelContext(again.container)
    check("lessons after reopening", fetch(LessonRecord.self, context).count, 4)
    check("phrases after reopening", fetch(PhraseRecord.self, context).count, from == "v1" ? 1 : 2)
} catch {
    check("reopening", "\(error)", "no error")
}

// Keeping a store aside moves its files into "Progress kept aside/<time>/" and deletes nothing.
do {
    let copy = url.deletingLastPathComponent().appending(path: "aside-\(from)/Georgian.store")
    try FileManager.default.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
    for (a, b) in zip(ProgressStore.files(of: url), ProgressStore.files(of: copy))
    where FileManager.default.fileExists(atPath: a.path) {
        try FileManager.default.copyItem(at: a, to: b)
    }
    let folder = try ProgressStore.setAside(copy)
    check("kept-aside store gone from its place", FileManager.default.fileExists(atPath: copy.path), false)
    check("kept-aside store in its folder", FileManager.default.fileExists(atPath: folder.appending(path: "Georgian.store").path), true)
    let fresh = try ProgressStore.open(at: copy)
    check("a fresh store after keeping aside", (try? ModelContext(fresh.container).fetchCount(FetchDescriptor<LessonRecord>())) ?? -1, 0)
} catch {
    check("keeping aside", "\(error)", "no error")
}

print("\(from): \(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
