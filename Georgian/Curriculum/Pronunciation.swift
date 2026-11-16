import Foundation

/// Pronunciation help in plain words, made from the letters a word actually contains.
/// Georgian is written as it sounds, so the letters that are new to English speakers are
/// what needs explaining.
enum Pronunciation {
    /// Letters with a sound English doesn't have, or that English speakers get wrong.
    static let tricky: Set<String> = ["თ", "კ", "პ", "ჟ", "რ", "ტ", "ფ", "ქ", "ღ", "ყ", "ჩ", "ც", "ძ", "წ", "ჭ", "ხ"]

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
    static let general = "Say every letter: none are silent. Stress is light, usually on the first syllable."
}
