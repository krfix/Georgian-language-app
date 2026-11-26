import Foundation

/// What a lesson says aloud by itself (owner, KART #18: "play by itself when I open a card
/// and when I select an answer"), when "Play Georgian automatically" is on. One rule
/// throughout: never before the answer if hearing it would give the answer away (reading a
/// word, recognising a letter by its sound, matching letters); those are heard after Check.
/// Listening exercises play their sound themselves, whatever the setting. The web app has
/// the same rules (web/js/engine.js `autoSpeech`): change both together.
enum AutoSpeech {
    /// The exercise appears.
    static func onShow(_ ex: Exercise) -> String? {
        switch ex.content {
        case .teachLetter(let l): return l.char
        case .teachWord(let w): return w.ka
        case .choice(let c):
            guard c.promptIsGeorgian, !c.prompt.contains("_"), !givesAway(ex.kind) else { return nil }
            return c.prompt
        case .typing(let t): return t.prompt
        case .flashcard(let f): return f.front
        case .dialogue(let d):
            // What the partner just said, if they spoke last.
            guard let last = d.history.last, !last.isLearner else { return nil }
            return last.ka
        case .note, .matching, .tiles: return nil
        }
    }

    /// The learner picks an answer (before Check): the Georgian they picked.
    static func onPick(_ ex: Exercise, from old: Answer?, to new: Answer?) -> String? {
        switch (ex.content, new) {
        case (.choice(let c), .choice(let i)?):
            guard c.optionsAreGeorgian, !givesAway(ex.kind), c.options.indices.contains(i) else { return nil }
            return c.options[i].text
        case (.dialogue(let d), .choice(let i)?):
            return d.options.indices.contains(i) ? d.options[i] : nil
        case (.tiles(let t), .tiles(let now)?):
            // A word tile just added to a sentence (letters alone would spell the answer out).
            guard !t.isSpelling else { return nil }
            var before: [String] = []
            if case .tiles(let b)? = old { before = b }
            guard now.count > before.count else { return nil }
            return now.last
        default: return nil
        }
    }

    /// A tile tapped in a matching exercise: a Georgian word, never a single letter (its
    /// sound would show which Latin letter it goes with).
    static func onMatchTap(_ georgian: String) -> String? {
        georgian.count > 1 ? georgian : nil
    }

    /// The answer has been checked: the whole Georgian, once it can't give anything away.
    static func onCheck(_ ex: Exercise, given: Answer, correct: Bool) -> String? {
        switch ex.content {
        case .choice(let c):
            guard c.options.indices.contains(c.answer) else { return nil }
            let right = c.options[c.answer].text
            if ex.kind == .listening { return nil }  // already heard
            if c.promptIsGeorgian && c.prompt.contains("_") {
                // The word or sentence with its gap filled.
                let gap = c.prompt.contains("___") ? "___" : "_"
                return c.prompt.replacingOccurrences(of: gap, with: right)
            }
            if givesAway(ex.kind) { return c.promptIsGeorgian ? c.prompt : (c.optionsAreGeorgian ? right : nil) }
            // Georgian options: the right one, if a wrong one was picked (that one was heard).
            if c.optionsAreGeorgian && !correct { return right }
            return nil
        case .tiles(let t):
            return t.answer.joined(separator: t.joiner)
        case .dialogue(let d):
            return correct ? nil : d.line.ka
        default:
            return nil
        }
    }

    /// Exercises where hearing the Georgian before answering tells you the answer.
    static func givesAway(_ kind: ExerciseKind) -> Bool {
        [.letterRecognition, .reading, .listening].contains(kind)
    }
}
