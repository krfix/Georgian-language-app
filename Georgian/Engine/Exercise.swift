import Foundation

/// The kinds of exercise the lesson player knows. Each kind is drawn by one reusable view
/// for its `Exercise.Content` shape (Features/Lesson).
enum ExerciseKind: String, Codable, CaseIterable {
    case teachLetter, teachWord, note
    case letterRecognition, multipleChoice, reading, missingLetter, fillBlank, listening
    case translation, matching, sentenceBuilder, spelling, flashcard, dialogue

    /// Teaching cards are read, not answered.
    var isGraded: Bool { ![.teachLetter, .teachWord, .note].contains(self) }
}

struct ChoiceOption: Hashable, Identifiable {
    let id: Int
    let text: String
    /// Small text under the option (a Latin spelling).
    let detail: String?
}

struct Choice: Hashable {
    let prompt: String
    let promptIsGeorgian: Bool
    /// Small text under the prompt (Latin spelling, or the English of a fill-in sentence).
    let promptDetail: String?
    let options: [ChoiceOption]
    let optionsAreGeorgian: Bool
    let answer: Int
    let explanation: String?
    /// Georgian to play: a listening exercise plays it instead of showing the prompt.
    let audioText: String?
}

struct Typing: Hashable {
    let prompt: String
    let promptLatin: String
    /// Every answer that counts as right (already in the evaluator's plain form).
    let accepted: [String]
    /// The answer shown when it's wrong.
    let display: String
}

struct MatchPair: Hashable, Identifiable {
    let id: String
    let georgian: String
    let other: String
}

struct Tiles: Hashable {
    let prompt: String
    let promptDetail: String?
    let answer: [String]
    /// The tiles to choose from: the answer's and some extra, mixed.
    let bank: [String]
    /// "" for spelling a word letter by letter, " " for a sentence.
    let joiner: String
    let isSpelling: Bool
}

struct Flashcard: Hashable {
    let front: String
    let frontLatin: String
    let back: String
    let note: String?
}

struct DialogueTurn: Hashable {
    let partner: String
    /// The lines said so far, shown as chat bubbles.
    let history: [DialogueLine]
    let line: DialogueLine
    let options: [String]
    let answer: Int
}

struct Exercise: Identifiable, Hashable {
    let id: String
    let kind: ExerciseKind
    let instruction: String
    /// The letter or word practised (for its review schedule); nil for whole sentences.
    let itemID: String?
    let content: Content

    enum Content: Hashable {
        case teachLetter(LetterInfo)
        case teachWord(Word)
        case note(GrammarNote)
        case choice(Choice)
        case typing(Typing)
        case matching([MatchPair])
        case tiles(Tiles)
        case flashcard(Flashcard)
        case dialogue(DialogueTurn)
    }

    var isGraded: Bool { kind.isGraded }

    /// The same exercise again, as a retry at the end of the lesson.
    func retry() -> Exercise {
        Exercise(id: id + "+", kind: kind, instruction: instruction, itemID: itemID, content: content)
    }
}

/// What the learner gave.
enum Answer: Hashable {
    case choice(Int)
    case text(String)
    case tiles([String])
    /// Matching: how many wrong pairings were tried before all were matched.
    case matched(mistakes: Int)
    /// Flashcard: the learner's own verdict.
    case recalled(Bool)
}

enum Verdict: Equatable {
    case correct
    /// Right, with a small typo.
    case almost
    case wrong

    var countsAsCorrect: Bool { self != .wrong }
}

struct Evaluation: Equatable {
    let verdict: Verdict
    /// The right answer, to show after a mistake or a typo.
    let correctAnswer: String
    let explanation: String?
}
