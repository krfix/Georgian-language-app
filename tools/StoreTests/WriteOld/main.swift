import Foundation
import SwiftData

// Writes a store the way an OLD version of the app did, with the old models (old/v1 or
// old/v2) and opened exactly as that app opened it. Compiled by run.sh with -D V1 or -D V2.
// Usage: write-old <store path>
// What it writes is what CheckNew/main.swift expects to find.

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let day: TimeInterval = 86_400
let start = Date(timeIntervalSince1970: 1_790_000_000)   // a fixed moment, so checks are exact

#if V1
let schema = Schema(versionedSchema: GeorgianSchemaV1.self)
#else
let schema = Schema(versionedSchema: GeorgianSchemaV2.self)
#endif

do {
    let config = ModelConfiguration(schema: schema, url: url)
    let container = try ModelContainer(for: schema, migrationPlan: GeorgianMigrationPlan.self, configurations: config)
    let context = ModelContext(container)

    let profile = LearnerProfile()
    profile.name = "Test learner"
    profile.levelRaw = "someLetters"
    profile.dailyGoal = 30
    profile.onboardingDone = true
    profile.appearance = "dark"
    profile.remindersOn = true
    profile.reminderHour = 8
    context.insert(profile)

    for (i, id) in ["a1", "a2", "a3"].enumerated() {
        context.insert(LessonRecord(lessonID: id, completedAt: start.addingTimeInterval(Double(i) * day),
                                    accuracy: 0.9, xp: 20, perfect: i == 1))
    }
    for (i, id) in ["letter-ა", "w-gamarjoba", "pb-es-ra-ghirs"].enumerated() {
        let m = MasteryRecord(itemID: id)
        m.ease = 2.2 + Double(i) / 10
        m.interval = 3 + i
        m.repetitions = 2
        m.due = start.addingTimeInterval(Double(3 + i) * day)
        m.lapses = i
        m.correctCount = 5
        m.wrongCount = i
        m.lastSeen = start
        context.insert(m)
    }
    context.insert(AnswerRecord(itemID: "w-gamarjoba", exerciseKind: "multipleChoice", correct: false,
                                given: "goodbye", expected: "hello", prompt: "გამარჯობა", date: start))
    context.insert(AnswerRecord(itemID: "w-gamarjoba", exerciseKind: "multipleChoice", correct: true,
                                given: "hello", expected: "hello", prompt: "გამარჯობა", date: start.addingTimeInterval(60)))
    let d = DayRecord(day: "2026-09-21")
    d.xp = 42
    d.lessons = 2
    d.answers = 17
    d.correctAnswers = 15
    d.challengeDone = true
    context.insert(d)
    context.insert(AchievementRecord(achievementID: "first-lesson", unlockedAt: start))
    context.insert(ReviewSessionRecord(date: start, items: 10, correct: 8, xp: 13))
    #if !V1
    let r = PhraseRecord(phraseID: "pb-es-ra-ghirs")
    r.saved = true
    r.list = "For the bazaar"
    r.learned = true
    r.opens = 4
    r.lastOpened = start
    context.insert(r)
    #endif
    try context.save()
    print("wrote \(url.lastPathComponent)")
} catch {
    print("FAIL: the old version couldn't write its store: \(error)")
    exit(1)
}
