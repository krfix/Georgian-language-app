import Foundation

// The phrasebook as stored in Resources/Curriculum/phrasebook.json (built and checked by
// tools/curriculum/build_curriculum.py from content_phrasebook.py). Plain data, no SwiftUI,
// so the tests can use it. Kept apart from the course: everything here is usable at once,
// without lessons.

struct PhraseSubcategory: Codable, Hashable, Identifiable {
    let id: String
    let title: String
}

/// A real-life situation: Transport, Shopping, Health…
struct PhraseCategory: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let ka: String
    let lat: String
    let symbol: String
    let color: String
    let blurb: String
    let subs: [PhraseSubcategory]

    var isEmergency: Bool { id == "emergency" }
    func sub(_ id: String) -> PhraseSubcategory? { subs.first { $0.id == id } }
}

/// Another way to say a phrase (a polite or informal form), or a reply you may hear.
struct PhraseForm: Codable, Hashable {
    let label: String?
    let ka: String
    let lat: String
    let en: String
}

/// A part of the course that explains something in the phrase.
struct GrammarLink: Codable, Hashable {
    let lesson: String
    let why: String
}

enum PhraseRegister: String {
    case polite, informal

    var title: String { self == .polite ? tr("Polite") : tr("Informal") }
    var explanation: String {
        switch self {
        case .polite: return tr("The polite form: for strangers, shops, older people and officials.")
        case .informal: return tr("For friends, family and children.")
        }
    }
}

struct Phrase: Codable, Hashable, Identifiable {
    let id: String
    let ka: String
    let lat: String
    /// An English-style sound guide, syllable by syllable: "gah-mahr-joh-bah".
    let sound: String
    let en: String
    let category: String
    let sub: String
    let keywords: [String]
    /// For emergencies: shown in red, kept apart from everyday phrases.
    let urgent: Bool
    let reg: String?
    let lit: String?
    let note: String?
    let variants: [PhraseForm]?
    let replies: [PhraseForm]?
    /// Course words that appear in the phrase.
    let words: [String]?
    let grammar: [GrammarLink]?

    var register: PhraseRegister? { reg.flatMap(PhraseRegister.init) }
}

struct PhraseDialogueLine: Codable, Hashable {
    /// 0: you, 1: the other person.
    let who: Int
    let ka: String
    let lat: String
    let en: String
}

struct DialogueNote: Codable, Hashable {
    let ka: String
    let lat: String
    let en: String
    let why: String
}

/// A short everyday conversation: a passenger and a driver, a customer and a seller…
struct PhraseDialogue: Codable, Hashable, Identifiable {
    let id: String
    let category: String
    let title: String
    /// [you, them], e.g. ["You", "Driver"].
    let roles: [String]
    let lines: [PhraseDialogueLine]
    let notes: [DialogueNote]
}

struct PhrasebookFile: Codable {
    let version: Int
    /// "claude" until a native speaker has checked the phrasebook, then "native".
    let checkedBy: String
    let categories: [PhraseCategory]
    let phrases: [Phrase]
    let dialogues: [PhraseDialogue]
    let synonyms: [String: [String]]
    let suggestions: [String]

    static let empty = PhrasebookFile(version: 0, checkedBy: "claude", categories: [], phrases: [], dialogues: [],
                                      synonyms: [:], suggestions: [])
}
