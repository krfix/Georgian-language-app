import Foundation

/// The phrasebook, loaded once with the course: situations, phrases, dialogues and search.
/// Phrases join the learning side as `Word`s with ids starting "pb-", so saving one for
/// practice puts it in the same spaced-repetition review as the course's words.
final class Phrasebook {
    let categories: [PhraseCategory]
    let phrases: [Phrase]
    let dialogues: [PhraseDialogue]
    let suggestions: [String]
    /// "claude" or "native": who has checked the Georgian.
    let checkedBy: String
    let search: PhraseSearch

    private let phraseByID: [String: Phrase]
    private let categoryByID: [String: PhraseCategory]
    private let dialogueByID: [String: PhraseDialogue]

    init(file: PhrasebookFile, courseWords: [Word] = [], courseCategories: [WordCategory] = []) {
        categories = file.categories
        phrases = file.phrases
        dialogues = file.dialogues
        suggestions = file.suggestions
        checkedBy = file.checkedBy
        phraseByID = Dictionary(file.phrases.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        categoryByID = Dictionary(file.categories.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        dialogueByID = Dictionary(file.dialogues.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        search = PhraseSearch(file: file, courseWords: courseWords, courseCategories: courseCategories)
    }

    static func isPhraseID(_ id: String) -> Bool { id.hasPrefix("pb-") }

    func phrase(_ id: String) -> Phrase? { phraseByID[id] }
    func category(_ id: String) -> PhraseCategory? { categoryByID[id] }
    func dialogue(_ id: String) -> PhraseDialogue? { dialogueByID[id] }

    func phrases(in category: String, sub: String? = nil) -> [Phrase] {
        phrases.filter { $0.category == category && (sub == nil || $0.sub == sub) }
    }

    func dialogues(in category: String) -> [PhraseDialogue] { dialogues.filter { $0.category == category } }

    var isNativeChecked: Bool { checkedBy == "native" }

    // MARK: Phrases on the learning side

    /// A phrase as a `Word`, for review and the word card.
    func word(for p: Phrase) -> Word {
        let plainEnglish = p.en.trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        var alt = [plainEnglish]
        for v in p.variants ?? [] where !alt.contains(v.en) { alt.append(v.en.trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))) }
        return Word(id: p.id, ka: p.ka, lat: p.lat, en: p.en, alt: alt, category: p.category, situation: p.sub,
                    example: Gloss(ka: p.ka, lat: p.lat, en: p.en), note: p.note ?? p.lit.map { "Literally: \($0)" }, pron: nil)
    }

    func word(_ id: String) -> Word? { phrase(id).map(word(for:)) }

    /// Other phrases to mix with one in review: the same situation first.
    func words(near w: Word) -> [Word] {
        let same = phrases.filter { $0.category == w.category && $0.id != w.id }
        let rest = phrases.filter { $0.category != w.category }
        return (same + rest).map(word(for:))
    }

    // MARK: Dialogue practice

    /// A dialogue as a conversation lesson for the lesson player: the learner plays one side
    /// (`role` 0 or 1) and chooses each of its lines among two others from the dialogue.
    func practiceLesson(_ d: PhraseDialogue, role: Int) -> Lesson {
        let texts = d.lines.map(\.ka)
        var lines: [DialogueLine] = []
        for (i, line) in d.lines.enumerated() {
            let mine = line.who == role
            var wrong: [String] = []
            if mine {
                // Lines from further on in the conversation: plausible Georgian, wrong here.
                for step in [3, 5, 2, 4, 1, 6, 7] where wrong.count < 2 {
                    let t = texts[(i + step) % texts.count]
                    if t != line.ka && !wrong.contains(t) { wrong.append(t) }
                }
                if wrong.count < 2 {
                    for other in dialogues where other.id != d.id {
                        for l in other.lines where wrong.count < 2 && l.ka != line.ka && !wrong.contains(l.ka) { wrong.append(l.ka) }
                    }
                }
            }
            let speaker = d.roles.indices.contains(line.who) ? d.roles[line.who] : "?"
            lines.append(DialogueLine(speaker: mine ? "You" : speaker, ka: line.ka, lat: line.lat, en: line.en,
                                      isLearner: mine, wrong: mine ? wrong : nil))
        }
        let partner = d.roles.indices.contains(1 - role) ? d.roles[1 - role] : "Them"
        let roleName = d.roles.indices.contains(role) ? d.roles[role] : "You"
        return Lesson(id: "\(d.id).as\(role)", kind: .conversation, title: d.title,
                      subtitle: role == 0 ? "You speak" : "You are the \(roleName.lowercased())",
                      letters: nil, pairs: nil, note: nil, read: nil, words: nil, category: d.category, situation: nil,
                      notes: nil, exercises: nil, dialogue: Dialogue(partner: partner, lines: lines))
    }
}
