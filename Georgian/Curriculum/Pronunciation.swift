import Foundation

/// Pronunciation help in plain words, made from the letters a word actually contains.
/// Georgian is written as it sounds, so the letters that are new to the learner are what
/// needs explaining: different ones for English and Polish speakers (the sounds come from
/// letters.json or letters-pl.json).
enum Pronunciation {
    /// Letters with a sound English doesn't have, or that English speakers get wrong.
    static let trickyForEnglish: Set<String> = ["თ", "კ", "პ", "ჟ", "რ", "ტ", "ფ", "ქ", "ღ", "ყ", "ჩ", "ც", "ძ", "წ", "ჭ", "ხ"]
    /// For Polish speakers: the air/no-air pairs, ღ and ყ, and ვ and ჟ (whose Latin v and zh
    /// read differently in Polish). ხ, ჩ, ც, ძ, შ, ჯ are ordinary Polish sounds.
    static let trickyForPolish: Set<String> = ["თ", "კ", "პ", "ტ", "ფ", "ქ", "ღ", "ყ", "წ", "ჭ", "ჩ", "ც", "ვ", "ჟ", "ი"]

    static var tricky: Set<String> { AppLanguage.current == .pl ? trickyForPolish : trickyForEnglish }

    /// One line per tricky letter in the text, in the order they first appear.
    static func hints(for georgian: String, in curriculum: Curriculum) -> [String] {
        var seen: [String] = []
        for ch in georgian.map(String.init) where tricky.contains(ch) && !seen.contains(ch) {
            seen.append(ch)
        }
        return seen.compactMap { c in
            guard let l = curriculum.letter(c) else { return nil }
            return "\(l.char) (\(l.latin)): \(l.sound)"
        }
    }

    /// The general rule, shown with every word.
    static var general: String { tr("Say every letter: none are silent. Stress is light, usually on the first syllable.") }
}
