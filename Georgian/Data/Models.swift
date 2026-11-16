import Foundation
import SwiftData

// What is saved on the phone (SwiftData). Every property has a default and nothing is
// marked unique, so the same models can later sync through CloudKit. `courseID` keeps room
// for more courses. Any change to these needs a new schema version (see GeorgianSchema).

@Model final class LearnerProfile {
    var name: String = ""
    var levelRaw: String = "beginner"
    var dailyGoal: Int = 20
    var onboardingDone: Bool = false
    var createdAt: Date = Date()
    var slowAudio: Bool = false
    var hapticsOn: Bool = true
    var remindersOn: Bool = false
    var reminderHour: Int = 19
    var reminderMinute: Int = 0
    /// "system", "light" or "dark".
    var appearance: String = "system"
    var courseID: String = "georgian-a0"

    init() {}

    var level: StartingLevel { StartingLevel(rawValue: levelRaw) ?? .beginner }
}

@Model final class LessonRecord {
    var lessonID: String = ""
    var completedAt: Date = Date()
    var accuracy: Double = 0
    var xp: Int = 0
    var perfect: Bool = false
    var courseID: String = "georgian-a0"

    init(lessonID: String, completedAt: Date, accuracy: Double, xp: Int, perfect: Bool) {
        self.lessonID = lessonID
        self.completedAt = completedAt
        self.accuracy = accuracy
        self.xp = xp
        self.perfect = perfect
    }
}

/// One letter's or word's review schedule.
@Model final class MasteryRecord {
    var itemID: String = ""
    var ease: Double = 2.5
    var interval: Int = 0
    var repetitions: Int = 0
    var due: Date = Date()
    var lapses: Int = 0
    var correctCount: Int = 0
    var wrongCount: Int = 0
    var lastSeen: Date = Date()
    var courseID: String = "georgian-a0"

    init(itemID: String) { self.itemID = itemID }

    var state: ReviewState {
        get { ReviewState(ease: ease, interval: interval, repetitions: repetitions, due: due, lapses: lapses) }
        set {
            ease = newValue.ease
            interval = newValue.interval
            repetitions = newValue.repetitions
            due = newValue.due
            lapses = newValue.lapses
        }
    }
}

/// An answer given in a lesson or review (kept for "previously wrong" and accuracy).
@Model final class AnswerRecord {
    var itemID: String = ""
    var exerciseKind: String = ""
    var correct: Bool = false
    var given: String = ""
    var expected: String = ""
    var prompt: String = ""
    var date: Date = Date()

    init(itemID: String, exerciseKind: String, correct: Bool, given: String, expected: String, prompt: String, date: Date) {
        self.itemID = itemID
        self.exerciseKind = exerciseKind
        self.correct = correct
        self.given = given
        self.expected = expected
        self.prompt = prompt
        self.date = date
    }
}

/// One day's activity, by local day key ("yyyy-MM-dd").
@Model final class DayRecord {
    var day: String = ""
    var xp: Int = 0
    var lessons: Int = 0
    var perfectLessons: Int = 0
    var reviewed: Int = 0
    var answers: Int = 0
    var correctAnswers: Int = 0
    var challengeDone: Bool = false

    init(day: String) { self.day = day }
}

@Model final class AchievementRecord {
    var achievementID: String = ""
    var unlockedAt: Date = Date()

    init(achievementID: String, unlockedAt: Date) {
        self.achievementID = achievementID
        self.unlockedAt = unlockedAt
    }
}

@Model final class ReviewSessionRecord {
    var date: Date = Date()
    var items: Int = 0
    var correct: Int = 0
    var xp: Int = 0

    init(date: Date, items: Int, correct: Int, xp: Int) {
        self.date = date
        self.items = items
        self.correct = correct
        self.xp = xp
    }
}

/// A phrasebook phrase the learner has touched: saved to their phrasebook (in a list of
/// their own, or none), marked as learned, or opened recently. Added in schema version 2.
@Model final class PhraseRecord {
    var phraseID: String = ""
    var saved: Bool = false
    var savedAt: Date = Date()
    /// The learner's own list ("For the landlord"); "" for none.
    var list: String = ""
    var learned: Bool = false
    var lastOpened: Date = Date.distantPast
    var opens: Int = 0
    var courseID: String = "georgian-a0"

    init(phraseID: String) { self.phraseID = phraseID }
}

enum GeorgianSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [LearnerProfile.self, LessonRecord.self, MasteryRecord.self, AnswerRecord.self,
         DayRecord.self, AchievementRecord.self, ReviewSessionRecord.self]
    }
}

/// Version 2 adds the phrasebook's `PhraseRecord`; nothing else changes, so the step from 1
/// is a lightweight one and all progress is kept.
enum GeorgianSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [LearnerProfile.self, LessonRecord.self, MasteryRecord.self, AnswerRecord.self,
         DayRecord.self, AchievementRecord.self, ReviewSessionRecord.self, PhraseRecord.self]
    }
}

enum GeorgianMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [GeorgianSchemaV1.self, GeorgianSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: GeorgianSchemaV1.self, toVersion: GeorgianSchemaV2.self)]
    }
}
