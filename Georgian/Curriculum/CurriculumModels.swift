import Foundation

// The course content as stored in Resources/Curriculum/*.json (built and checked by
// tools/curriculum/build_curriculum.py). Plain data: no SwiftUI here, so the tests can use it.

/// Georgian text with its Latin spelling and English meaning.
struct Gloss: Codable, Hashable {
    let ka: String
    let lat: String
    let en: String
}

struct LetterInfo: Codable, Hashable, Identifiable {
    let char: String
    let name: String
    let latin: String
    let sound: String
    let word: String
    let wordLatin: String
    let meaning: String
    let tip: String

    var id: String { char }
    /// The id used for this letter's progress and review.
    var itemID: String { "letter-" + char }
}

struct WordCategory: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let symbol: String
    let color: String
}

struct Word: Codable, Hashable, Identifiable {
    let id: String
    let ka: String
    let lat: String
    let en: String
    let alt: [String]
    let category: String
    let situation: String?
    let example: Gloss
    let note: String?
    let pron: String?

    /// One word (not a phrase): a candidate for spelling with letter tiles.
    var isSingleWord: Bool { !ka.contains(" ") }
    /// The Georgian without question marks and full stops.
    var bare: String { ka.trimmingCharacters(in: CharacterSet(charactersIn: ".?!")) }
}

struct GrammarNote: Codable, Hashable {
    let title: String
    let text: String
    let table: [Gloss]
}

/// An exercise written by hand in the course (grammar and conversation lessons).
struct ExerciseSpec: Codable, Hashable {
    let type: String            // "choice", "fill" or "build"
    let prompt: String?
    let options: [String]?
    let answer: Int?
    let explanation: String?
    let sentence: String?       // fill: Georgian with ___
    let translation: String?
    let english: String?        // build: the sentence to make
    let tiles: [String]?
    let extra: [String]?
    let tilesLatin: [String]?
}

struct DialogueLine: Codable, Hashable {
    let speaker: String
    let ka: String
    let lat: String
    let en: String
    let isLearner: Bool
    let wrong: [String]?
}

struct Dialogue: Codable, Hashable {
    let partner: String
    let lines: [DialogueLine]
}

enum LessonKind: String, Codable, Hashable {
    case letters, contrast, vocabulary, phrases, grammar, conversation
}

struct Lesson: Codable, Hashable, Identifiable {
    let id: String
    let kind: LessonKind
    let title: String
    let subtitle: String
    let letters: [String]?
    let pairs: [[String]]?
    let note: String?
    let read: [Gloss]?
    let words: [String]?
    let category: String?
    let situation: String?
    let notes: [GrammarNote]?
    let exercises: [ExerciseSpec]?
    let dialogue: Dialogue?
    /// A short "why" card shown before the exercises (KART #4).
    var intro: GrammarNote? = nil
}

struct CourseModule: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let color: String
    let intro: String
    let lessons: [Lesson]
}

struct CourseFile: Codable {
    let id: String
    let version: Int
    let title: String
    let modules: [CourseModule]
}

struct LettersFile: Codable {
    let version: Int
    let letters: [LetterInfo]
    let lookalikes: [[String]]
}

/// What one Georgian word in a sentence is, and why it looks the way it does (tap a word:
/// TappableGeorgian). Built by build_curriculum.py from content_glossary.py.
struct GlossaryEntry: Codable, Hashable {
    let lat: String
    /// What this form means here (verbs, irregular words); nil when the base says it.
    let meaning: String?
    /// The dictionary form, when this word is a changed form of it.
    let base: String?
    let baseLat: String?
    let baseMeaning: String?
    /// Why it looks like this: the ending, the person, the polite -თ…
    let note: String?
}

struct GlossaryFile: Codable {
    let version: Int
    let words: [String: GlossaryEntry]
}

struct VocabularyFile: Codable {
    let version: Int
    let categories: [WordCategory]
    let words: [Word]
}
