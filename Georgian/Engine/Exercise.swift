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

    /// What the exercise shows, in a line, for a mistake report.
    var promptText: String {
        switch content {
        case .choice(let c): return c.audioText.map { "\($0) (\(tr("listening")))" } ?? c.prompt
        case .typing(let t): return t.prompt
        case .tiles(let t): return t.prompt
        case .flashcard(let f): return f.front
        case .dialogue(let d): return d.history.last?.ka ?? d.partner
        case .teachLetter(let l): return "\(l.char) \(l.latin) · \(l.word) \(l.wordLatin), \(l.meaning)"
        case .teachWord(let w): return "\(w.ka) \(w.lat), \(w.en)"
        case .note(let n): return n.title
        case .matching(let pairs): return pairs.map { "\($0.georgian) = \($0.other)" }.joined(separator: "; ")
        }
    }

    /// Everything a mistake report needs to find this exercise again (KART #16).
    func reportLines(lessonTitle: String, given: String?, shownAnswer: String?) -> [String] {
        var out = [tr("Lesson: {0}", lessonTitle), tr("Exercise: {0} ({1})", instruction, kind.rawValue), promptText]
        if case .choice(let c) = content { out.append(tr("Options: {0}", c.options.map(\.text).joined(separator: " / "))) }
        if case .dialogue(let d) = content { out.append(tr("Options: {0}", d.options.joined(separator: " / "))) }
        if let given, !given.isEmpty { out.append(tr("My answer: {0}", given)) }
        if let shownAnswer, !shownAnswer.isEmpty { out.append(tr("Answer shown: {0}", shownAnswer)) }
        return out
    }

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
