import Foundation

/// What a lesson says aloud by itself (owner, KART #18), when "Play Georgian automatically"
/// is on: the Georgian on screen as an exercise appears, unless hearing it first would give
/// the answer away (a word to read, a letter to recognise, a gap); every Georgian answer the
/// learner taps, each time; and after Check, only a wrong answer, with the right Georgian.
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

    /// The learner taps an answer (before Check), every time, even the same one again: the
    /// Georgian they tapped (owner, KART #18). English or Latin answers have none.
    static func onPick(_ ex: Exercise, from old: Answer?, to new: Answer?) -> String? {
        switch (ex.content, new) {
        case (.choice(let c), .choice(let i)?):
            guard c.optionsAreGeorgian, c.options.indices.contains(i) else { return nil }
            return c.options[i].text
        case (.dialogue(let d), .choice(let i)?):
            return d.options.indices.contains(i) ? d.options[i] : nil
        case (.tiles, .tiles(let now)?):
            // The tile just added (a word, or a letter when spelling).
            var before: [String] = []
            if case .tiles(let b)? = old { before = b }
            guard now.count > before.count else { return nil }
            return now.last
        default: return nil
        }
    }

    /// A Georgian tile tapped in a matching exercise.
    static func onMatchTap(_ georgian: String) -> String? { georgian }

    /// The answer has been checked. Right: nothing more (it was heard when tapped). Wrong: the
    /// right Georgian once (the gap filled, the sentence built, the right option or reply, or
    /// the word or letter that was to be read or heard).
    static func onCheck(_ ex: Exercise, given: Answer, correct: Bool) -> String? {
        guard !correct else { return nil }
        switch ex.content {
        case .choice(let c):
            guard c.options.indices.contains(c.answer) else { return nil }
            let right = c.options[c.answer].text
            if c.promptIsGeorgian && c.prompt.contains("_") {
                let gap = c.prompt.contains("___") ? "___" : "_"
                return c.prompt.replacingOccurrences(of: gap, with: right)
            }
            if c.optionsAreGeorgian { return right }
            if let audio = c.audioText { return audio }
            return c.promptIsGeorgian ? c.prompt : nil
        case .tiles(let t):
            return t.answer.joined(separator: t.joiner)
        case .dialogue(let d):
            return d.line.ka
        default:
            return nil
        }
    }

    /// Exercises where hearing the Georgian as they appear tells you the answer.
    static func givesAway(_ kind: ExerciseKind) -> Bool {
        [.letterRecognition, .reading, .listening].contains(kind)
    }
}
