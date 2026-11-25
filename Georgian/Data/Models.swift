import Foundation
import SwiftData

// What is saved on the phone (SwiftData). Every property has a default and nothing is
// marked unique, so the same models can later sync through CloudKit. `courseID` keeps room
// for more courses.
//
// Each schema version below holds its OWN copy of the models, exactly as that version was
// shipped. SwiftData recognises an old store by comparing it with these copies, so a copy
// must never change once released: that is what lets every update open older progress.
// The app itself uses the newest version through the typealiases just below.
//
// To change what is saved (add a property, a model…):
//   1. copy the newest enum (say GeorgianSchemaV2) to GeorgianSchemaV3, with version 3.0.0,
//      and make the change only in the copy;
//   2. point the typealiases at GeorgianSchemaV3, and `ProgressStore.currentSchema` too;
//   3. add V3 to `GeorgianMigrationPlan.schemas` and a stage from V2 to V3
//      (`.lightweight` for added properties with defaults or added models, `.custom` otherwise);
//   4. add the old version to tools/StoreTests (a store written by it must open, with its
//      progress, in the new app), and run the tests on the Mac.
// Never edit V1 or V2 in place.

typealias LearnerProfile = GeorgianSchemaV2.LearnerProfile
typealias LessonRecord = GeorgianSchemaV2.LessonRecord
typealias MasteryRecord = GeorgianSchemaV2.MasteryRecord
typealias AnswerRecord = GeorgianSchemaV2.AnswerRecord
typealias DayRecord = GeorgianSchemaV2.DayRecord
typealias AchievementRecord = GeorgianSchemaV2.AchievementRecord
typealias ReviewSessionRecord = GeorgianSchemaV2.ReviewSessionRecord
typealias PhraseRecord = GeorgianSchemaV2.PhraseRecord

extension LearnerProfile {
    var level: StartingLevel { StartingLevel(rawValue: levelRaw) ?? .beginner }
}

extension MasteryRecord {
    /// One letter's or word's review schedule, as the spaced-repetition code sees it.
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

// MARK: - Version 2 (0.2.0 onwards): version 1 plus the phrasebook's PhraseRecord. Frozen.

enum GeorgianSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [LearnerProfile.self, LessonRecord.self, MasteryRecord.self, AnswerRecord.self,
         DayRecord.self, AchievementRecord.self, ReviewSessionRecord.self, PhraseRecord.self]
    }

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
    /// their own, or none), marked as learned, or opened recently.
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
}

// MARK: - Version 1 (the first builds, before the phrasebook). Frozen.

enum GeorgianSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [LearnerProfile.self, LessonRecord.self, MasteryRecord.self, AnswerRecord.self,
         DayRecord.self, AchievementRecord.self, ReviewSessionRecord.self]
    }

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
        var appearance: String = "system"
        var courseID: String = "georgian-a0"

        init() {}
    }

    @Model final class LessonRecord {
        var lessonID: String = ""
        var completedAt: Date = Date()
        var accuracy: Double = 0
        var xp: Int = 0
        var perfect: Bool = false
        var courseID: String = "georgian-a0"

        init() {}
    }

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

        init() {}
    }

    @Model final class AnswerRecord {
        var itemID: String = ""
        var exerciseKind: String = ""
        var correct: Bool = false
        var given: String = ""
        var expected: String = ""
        var prompt: String = ""
        var date: Date = Date()

        init() {}
    }

    @Model final class DayRecord {
        var day: String = ""
        var xp: Int = 0
        var lessons: Int = 0
        var perfectLessons: Int = 0
        var reviewed: Int = 0
        var answers: Int = 0
        var correctAnswers: Int = 0
        var challengeDone: Bool = false

        init() {}
    }

    @Model final class AchievementRecord {
        var achievementID: String = ""
        var unlockedAt: Date = Date()

        init() {}
    }

    @Model final class ReviewSessionRecord {
        var date: Date = Date()
        var items: Int = 0
        var correct: Int = 0
        var xp: Int = 0

        init() {}
    }
}

enum GeorgianMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [GeorgianSchemaV1.self, GeorgianSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: GeorgianSchemaV1.self, toVersion: GeorgianSchemaV2.self)]
    }
}
