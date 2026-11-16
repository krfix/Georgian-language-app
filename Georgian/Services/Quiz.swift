import Foundation

/// How well each letter is known: a box from 0 (just met, or missed last time) to 4 (known).
/// A right answer moves the letter up one box, a wrong one sends it back to 0. Letters in low
/// boxes come up more often. Kept in UserDefaults by `ProgressStore`; the rules are here, tested.
struct LetterProgress: Equatable {
    static let top = 4
    /// Letters never practised have no entry.
    var boxes: [String: Int] = [:]

    func box(_ char: String) -> Int { boxes[char] ?? 0 }
    func isSeen(_ char: String) -> Bool { boxes[char] != nil }
    func isKnown(_ char: String) -> Bool { box(char) >= Self.top }

    mutating func record(_ char: String, correct: Bool) {
        boxes[char] = correct ? min(box(char) + 1, Self.top) : 0
    }

    var knownCount: Int { boxes.values.filter { $0 >= Self.top }.count }
}

enum Quiz {
    /// How many letters are being learned at once: new letters join, in alphabetical order,
    /// only while fewer than this are still not known.
    static let working = 5
    static let optionCount = 4

    enum Direction: Equatable { case toLatin, toGeorgian }

    struct Question: Equatable {
        let letter: Letter
        let direction: Direction
        /// Four letters, the right one among them, in random order.
        let options: [Letter]

        var prompt: String { direction == .toLatin ? letter.char : letter.latin }
        func label(_ option: Letter) -> String { direction == .toLatin ? option.latin : option.char }
    }

    /// The letters the quiz asks about now: every letter already met, plus the next new ones
    /// so that `working` letters are still being learned (fewer once the alphabet runs out).
    static func pool(_ progress: LetterProgress, letters: [Letter] = Alphabet.letters) -> [Letter] {
        let seen = letters.filter { progress.isSeen($0.char) }
        let learning = seen.filter { !progress.isKnown($0.char) }.count
        let fresh = letters.filter { !progress.isSeen($0.char) }.prefix(max(0, working - learning))
        return seen + fresh
    }

    /// Letters in lower boxes weigh more: box 0 weighs 25, box 4 weighs 1.
    static func weight(_ box: Int) -> Int {
        let w = LetterProgress.top + 1 - min(max(box, 0), LetterProgress.top)
        return w * w
    }

    /// The next letter to ask, never the same as the one just asked (when there is a choice).
    static func pick<G: RandomNumberGenerator>(_ progress: LetterProgress, after last: String?, using rng: inout G) -> Letter {
        var pool = pool(progress)
        if pool.count > 1, let last { pool.removeAll { $0.char == last } }
        let total = pool.reduce(0) { $0 + weight(progress.box($1.char)) }
        var roll = Int.random(in: 0..<total, using: &rng)
        for letter in pool {
            roll -= weight(progress.box(letter.char))
            if roll < 0 { return letter }
        }
        return pool[pool.count - 1]
    }

    /// Wrong answers: look-alikes first (the letters people really mix up), then any others.
    /// No two options share a Latin spelling.
    static func options<G: RandomNumberGenerator>(for letter: Letter, using rng: inout G) -> [Letter] {
        let alike = Alphabet.lookalikes.filter { $0.contains(letter.char) }.flatMap { $0 }
        var chosen = [letter]
        func add(_ candidates: [Letter]) {
            for c in candidates.shuffled(using: &rng) where chosen.count < optionCount {
                if !chosen.contains(where: { $0.char == c.char || $0.latin == c.latin }) { chosen.append(c) }
            }
        }
        add(alike.compactMap(Alphabet.letter))
        add(Alphabet.letters)
        return chosen.shuffled(using: &rng)
    }

    /// A known letter is asked the other way round half the time (Latin → Georgian).
    static func question<G: RandomNumberGenerator>(_ progress: LetterProgress, after last: String?, using rng: inout G) -> Question {
        let letter = pick(progress, after: last, using: &rng)
        let flip = progress.box(letter.char) >= 2 && Bool.random(using: &rng)
        return Question(letter: letter, direction: flip ? .toGeorgian : .toLatin, options: options(for: letter, using: &rng))
    }
}

/// The same "random" numbers every time, for the tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
