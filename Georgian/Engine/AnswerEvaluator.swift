import Foundation

/// Decides whether an answer is right. Typed answers are compared in a plain form (no
/// capitals, punctuation or "the/a/to" at the start); one small typo still counts.
enum AnswerEvaluator {
    static func evaluate(_ exercise: Exercise, _ answer: Answer) -> Evaluation {
        switch (exercise.content, answer) {
        case (.choice(let c), .choice(let i)):
            let right = c.options.first { $0.id == c.answer }?.text ?? ""
            return Evaluation(verdict: i == c.answer ? .correct : .wrong, correctAnswer: right, explanation: c.explanation)

        case (.dialogue(let d), .choice(let i)):
            return Evaluation(verdict: i == d.answer ? .correct : .wrong, correctAnswer: d.line.ka, explanation: d.line.en)

        case (.typing(let t), .text(let s)):
            return Evaluation(verdict: typed(s, accepted: t.accepted), correctAnswer: t.display, explanation: nil)

        case (.tiles(let t), .tiles(let given)):
            let ok = given == t.answer || given.joined(separator: t.joiner) == t.answer.joined(separator: t.joiner)
            return Evaluation(verdict: ok ? .correct : .wrong, correctAnswer: t.answer.joined(separator: t.joiner), explanation: nil)

        case (.matching, .matched(let mistakes)):
            return Evaluation(verdict: mistakes == 0 ? .correct : .wrong, correctAnswer: "", explanation: nil)

        case (.flashcard(let f), .recalled(let knew)):
            return Evaluation(verdict: knew ? .correct : .wrong, correctAnswer: f.back, explanation: f.note)

        default:
            return Evaluation(verdict: .correct, correctAnswer: "", explanation: nil)
        }
    }

    /// The verdict for a typed answer against the accepted ones.
    static func typed(_ input: String, accepted: [String]) -> Verdict {
        let given = plain(input)
        guard !given.isEmpty else { return .wrong }
        if accepted.contains(where: { plain($0) == given }) { return .correct }
        for a in accepted.map(plain) where !a.isEmpty {
            let allowed = a.count >= 8 ? 2 : a.count >= 4 ? 1 : 0
            if allowed > 0 && distance(a, given) <= allowed { return .almost }
        }
        return .wrong
    }

    /// Lower case, straight apostrophes, no punctuation, single spaces, and without a leading
    /// "the", "a", "an" or "to".
    static func plain(_ s: String) -> String {
        var t = s.lowercased()
        for curly in ["’", "‘", "ʼ", "`", "´"] { t = t.replacingOccurrences(of: curly, with: "'") }
        t = String(t.map { ch -> Character in
            if ch.isLetter || ch.isNumber || ch == "'" { return ch }
            return " "
        })
        var words = t.split(separator: " ").map(String.init)
        while let first = words.first, ["the", "a", "an", "to"].contains(first), words.count > 1 {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }

    /// Edits needed to turn one text into the other (Levenshtein distance).
    static func distance(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var previous = Array(0...y.count)
        for i in 1...x.count {
            var current = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[y.count]
    }

    /// All the English answers a word accepts, in plain form.
    static func acceptedEnglish(for word: Word) -> [String] {
        var out: [String] = []
        // "hello (in reply)" also accepts "hello"; "week; Sunday" accepts each part.
        let main = word.en
        out.append(main)
        let noBrackets = main.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
        out.append(noBrackets)
        out.append(contentsOf: noBrackets.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) })
        out.append(contentsOf: word.alt)
        var seen = Set<String>()
        return out.map(plain).filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
