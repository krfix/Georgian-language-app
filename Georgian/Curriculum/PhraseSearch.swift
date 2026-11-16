import Foundation

/// Search across the phrasebook and the course, in English, Georgian or Latin letters.
/// Built once; no exact wording needed:
/// - English words are matched whole, by their start ("expens" → expensive), with one typo
///   allowed in longer words ("pharmcy"), through synonyms ("cab" → taxi) and simple plurals;
/// - little words (the, a, I, please…) are ignored unless they are all there is;
/// - every phrase also matches its keywords, its situation and its subcategory;
/// - Georgian is matched anywhere in the text; Latin ignores apostrophes ("tsqali" → ts'q'ali).
/// Results that match every word come first, then the closest wording, then shorter phrases.
struct PhraseSearch {
    struct Results {
        var phrases: [Phrase] = []
        var words: [Word] = []
        var dialogues: [PhraseDialogue] = []
        var categories: [PhraseCategory] = []

        var isEmpty: Bool { phrases.isEmpty && words.isEmpty && dialogues.isEmpty && categories.isEmpty }
    }

    private struct Doc {
        let english: Set<String>
        let keywords: Set<String>
        /// The situation and subcategory names: a weaker match than the phrase's own words.
        let context: Set<String>
        let latin: Set<String>
        let georgian: [String]
        /// The main English, plain, for whole-wording matches.
        let sentence: String
        let length: Int
    }

    private let phrases: [Phrase]
    private let phraseDocs: [Doc]
    private let words: [Word]
    private let wordDocs: [Doc]
    private let dialogues: [PhraseDialogue]
    private let dialogueDocs: [Doc]
    private let categories: [PhraseCategory]
    private let categoryDocs: [Doc]
    private let synonyms: [String: [String]]

    static let stopwords: Set<String> = ["a", "an", "the", "to", "of", "is", "are", "am", "i", "im", "me", "my", "it",
                                         "its", "please", "for", "and", "or", "be", "some", "any"]

    init(file: PhrasebookFile, courseWords: [Word], courseCategories: [WordCategory]) {
        synonyms = file.synonyms
        phrases = file.phrases
        let cats = Dictionary(file.categories.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        phraseDocs = file.phrases.map { p in
            let c = cats[p.category]
            let forms = (p.variants ?? [])
            let context = Set(Self.tokens((c?.title ?? "") + " " + (c?.sub(p.sub)?.title ?? "")))
            return Doc(english: Set(Self.tokens(([p.en, p.lit ?? ""] + forms.map(\.en)).joined(separator: " "))),
                       keywords: Set(p.keywords.flatMap(Self.tokens)), context: context,
                       latin: Set(Self.tokens(([p.lat] + forms.map(\.lat)).joined(separator: " "))),
                       georgian: [p.ka] + forms.map(\.ka),
                       sentence: Self.plain(p.en), length: p.en.count)
        }
        words = courseWords
        let wordCats = Dictionary(courseCategories.map { ($0.id, $0.title) }, uniquingKeysWith: { a, _ in a })
        wordDocs = courseWords.map { w in
            Doc(english: Set(Self.tokens(([w.en] + w.alt).joined(separator: " "))),
                keywords: [], context: Set(Self.tokens(wordCats[w.category] ?? "")),
                latin: Set(Self.tokens(w.lat)), georgian: [w.ka], sentence: Self.plain(w.en), length: w.en.count)
        }
        dialogues = file.dialogues
        dialogueDocs = file.dialogues.map { d in
            Doc(english: Set(Self.tokens(d.title + " " + d.lines.map(\.en).joined(separator: " "))),
                keywords: Set(Self.tokens(d.roles.joined(separator: " ") + " dialogue conversation")),
                context: Set(Self.tokens(cats[d.category]?.title ?? "")),
                latin: Set(Self.tokens(d.lines.map(\.lat).joined(separator: " "))),
                georgian: d.lines.map(\.ka), sentence: Self.plain(d.title), length: 40)
        }
        categories = file.categories
        categoryDocs = file.categories.map { c in
            Doc(english: Set(Self.tokens(c.title + " " + c.subs.map(\.title).joined(separator: " "))),
                keywords: Set(Self.tokens(c.blurb)), context: [], latin: Set(Self.tokens(c.lat)), georgian: [c.ka],
                sentence: Self.plain(c.title), length: c.title.count)
        }
    }

    // MARK: Searching

    func search(_ query: String, limit: Int = 40) -> Results {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return Results() }
        if Self.hasGeorgian(q) {
            return Results(phrases: georgian(q, phrases, phraseDocs, limit),
                           words: georgian(q, words, wordDocs, 12),
                           dialogues: georgian(q, dialogues, dialogueDocs, 4),
                           categories: georgian(q, categories, categoryDocs, 3))
        }
        var terms = Self.tokens(q).filter { !Self.stopwords.contains($0) }
        if terms.isEmpty { terms = Self.tokens(q) }
        guard !terms.isEmpty else { return Results() }
        let sentence = Self.plain(q)
        return Results(phrases: rank(terms, sentence, phrases, phraseDocs, limit),
                       words: rank(terms, sentence, words, wordDocs, 12),
                       dialogues: rank(terms, sentence, dialogues, dialogueDocs, 4, strict: true),
                       categories: rank(terms, sentence, categories, categoryDocs, 3, strict: true))
    }

    /// The best phrase for a query (tests and quick answers).
    func top(_ query: String, _ n: Int = 3) -> [Phrase] { Array(search(query, limit: n).phrases.prefix(n)) }

    private func rank<T>(_ terms: [String], _ sentence: String, _ items: [T], _ docs: [Doc], _ limit: Int,
                         strict: Bool = false) -> [T] {
        var scored: [(index: Int, matched: Int, score: Double)] = []
        for (i, doc) in docs.enumerated() {
            var matched = 0
            var score = 0.0
            for t in terms {
                let s = termScore(t, doc)
                if s > 0 { matched += 1; score += s }
            }
            let needed = strict ? terms.count : max(1, (terms.count + 1) / 2)
            guard matched >= needed else { continue }
            if !sentence.isEmpty && doc.sentence.contains(sentence) { score += doc.sentence.hasPrefix(sentence) ? 6 : 4 }
            score -= Double(doc.length) * 0.01
            scored.append((i, matched, score))
        }
        scored.sort { a, b in a.matched != b.matched ? a.matched > b.matched : (a.score != b.score ? a.score > b.score : a.index < b.index) }
        return scored.prefix(limit).map { items[$0.index] }
    }

    /// How well one search word matches a document: 0 for not at all.
    private func termScore(_ term: String, _ doc: Doc) -> Double {
        var best = match(term, doc, weight: 1)
        let stem = Self.stem(term)
        if stem != term { best = max(best, match(stem, doc, weight: 0.95)) }
        for alt in synonyms[term] ?? synonyms[stem] ?? [] where alt != term {
            best = max(best, match(alt, doc, weight: 0.8))
        }
        return best
    }

    private func match(_ t: String, _ doc: Doc, weight: Double) -> Double {
        if doc.english.contains(t) || doc.latin.contains(t) || doc.keywords.contains(t) { return 3 * weight }
        if doc.context.contains(t) { return 1.5 * weight }
        if t.count >= 3 {
            if doc.english.contains(where: { $0.hasPrefix(t) }) || doc.latin.contains(where: { $0.hasPrefix(t) }) { return 1.6 * weight }
            if doc.keywords.contains(where: { $0.hasPrefix(t) }) { return 1.4 * weight }
            if doc.context.contains(where: { $0.hasPrefix(t) }) { return 0.9 * weight }
        }
        if t.count >= 5 {
            let close: (String) -> Bool = { abs($0.count - t.count) <= 1 && AnswerEvaluator.distance($0, t) <= 1 }
            if doc.english.contains(where: close) || doc.keywords.contains(where: close) || doc.latin.contains(where: close) {
                return 1.0 * weight
            }
            if doc.context.contains(where: close) { return 0.6 * weight }
        }
        return 0
    }

    private func georgian<T>(_ q: String, _ items: [T], _ docs: [Doc], _ limit: Int) -> [T] {
        let needle = q.trimmingCharacters(in: CharacterSet(charactersIn: ".,?!"))
        var scored: [(Int, Double)] = []
        for (i, doc) in docs.enumerated() {
            var best = 0.0
            for g in doc.georgian {
                let bare = g.trimmingCharacters(in: CharacterSet(charactersIn: ".,?!"))
                if bare == needle { best = max(best, 10) }
                else if bare.hasPrefix(needle) { best = max(best, 7) }
                else if g.contains(needle) { best = max(best, 5) }
            }
            if best > 0 { scored.append((i, best - Double(doc.georgian.first?.count ?? 0) * 0.01)) }
        }
        scored.sort { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
        return scored.prefix(limit).map { items[$0.0] }
    }

    // MARK: Text

    /// Lower case, no apostrophes, letters and digits only, single spaces.
    static func plain(_ s: String) -> String {
        var t = s.lowercased()
        for a in ["'", "’", "‘", "ʼ", "`", "´"] { t = t.replacingOccurrences(of: a, with: "") }
        let mapped = String(t.map { $0.isLetter || $0.isNumber ? $0 : " " })
        return mapped.split(separator: " ").joined(separator: " ")
    }

    static func tokens(_ s: String) -> [String] { plain(s).split(separator: " ").map(String.init) }

    /// A plain English stem: phones → phone, pharmacies → pharmacy, training → train.
    static func stem(_ t: String) -> String {
        if t.count > 4 && t.hasSuffix("ies") { return String(t.dropLast(3)) + "y" }
        if t.count > 5 && t.hasSuffix("ing") { return String(t.dropLast(3)) }
        if t.count > 3 && t.hasSuffix("s") && !t.hasSuffix("ss") { return String(t.dropLast()) }
        return t
    }

    static func hasGeorgian(_ s: String) -> Bool { s.unicodeScalars.contains { (0x10D0...0x10FF).contains($0.value) } }
}
