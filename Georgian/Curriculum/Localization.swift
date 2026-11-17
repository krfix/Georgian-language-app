import Foundation

// The language the app speaks to the learner: English or Polish (KART #4). Georgian is the
// same in both; only the meanings, explanations and the app's own words change.
//
// - Screens and the engine write their text in English inside `tr("…")`; in Polish it is
//   looked up in Resources/Localization/pl.json (keys are the English text). A missing
//   entry shows the English, and tools/l10n/check_strings.py lists every one before a build.
// - Placeholders are {0}, {1}…: `tr("Lesson {0} of {1}", 3, 10)`, so Polish can reorder them.
// - Counts that need a plural use `plural(n, …)`: Polish has three forms (1 słowo, 2 słowa,
//   5 słów), English two.
// - The course and phrasebook come from their own files per language (course-pl.json…).
// Foundation only: the logic tests use it too.

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, pl

    var id: String { rawValue }

    /// The language's name in itself, for the picker.
    var nativeName: String {
        switch self {
        case .en: return "English"
        case .pl: return "Polski"
        }
    }

    var flag: String {
        switch self {
        case .en: return "🇬🇧"
        case .pl: return "🇵🇱"
        }
    }

    /// The end of the content files' names: course.json, course-pl.json.
    var fileSuffix: String { self == .en ? "" : "-" + rawValue }

    var locale: Locale { Locale(identifier: self == .en ? "en_GB" : "pl_PL") }

    static let defaultsKey = "appLanguage"

    /// The learner's choice, or the iPhone's language when they haven't chosen (Polish
    /// iPhones get Polish). The launch argument `-appLanguage pl` sets it too.
    static var stored: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: defaultsKey), let l = AppLanguage(rawValue: raw) { return l }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("pl") ? .pl : .en
    }

    /// The language in use now.
    private(set) static var current: AppLanguage = .en

    /// Switches the app's own words; the course is reloaded by the app (AppModel).
    static func use(_ language: AppLanguage, bundle: Bundle = .main, save: Bool = true) {
        if save { UserDefaults.standard.set(language.rawValue, forKey: defaultsKey) }
        current = language
        Localizer.load(language, bundle: bundle)
    }
}

/// The table of the app's own words in the current language.
enum Localizer {
    private(set) static var table: [String: String] = [:]

    static func load(_ language: AppLanguage, bundle: Bundle = .main) {
        guard language != .en else { table = [:]; return }
        let name = "ui-" + language.rawValue
        let url = bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Localization")
        guard let url, let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            table = [:]
            return
        }
        table = decoded
    }

    /// For the tests: a table given directly.
    static func load(table: [String: String]) { self.table = table }

    static func text(_ english: String) -> String { table[english] ?? english }
}

/// The app's own words in the learner's language. `english` is both the English text and
/// the key in the Polish table.
func tr(_ english: String) -> String { Localizer.text(english) }

/// The same, with {0}, {1}… replaced by the values in order.
func tr(_ english: String, _ values: Any...) -> String {
    var out = Localizer.text(english)
    for (i, v) in values.enumerated() {
        out = out.replacingOccurrences(of: "{\(i)}", with: "\(v)")
    }
    return out
}

/// A count with its noun in the right form: `plural(3, "word", "words", pl: ("słowo", "słowa", "słów"))`
/// gives "3 words" or "3 słowa". Without Polish forms the English is used.
func plural(_ n: Int, _ one: String, _ other: String, pl: (one: String, few: String, many: String)? = nil) -> String {
    switch AppLanguage.current {
    case .pl:
        guard let pl else { return "\(n) " + (n == 1 ? one : other) }
        return "\(n) " + PolishPlural.form(n, pl.one, pl.few, pl.many)
    case .en:
        return "\(n) " + (n == 1 ? one : other)
    }
}

/// Text without accents, for comparing what was typed: "zrozumiałem" and "zrozumialem" match,
/// as do "café" and "cafe". Georgian letters are left as they are.
func withoutAccents(_ s: String) -> String {
    s.folding(options: .diacriticInsensitive, locale: nil)
        .replacingOccurrences(of: "ł", with: "l").replacingOccurrences(of: "Ł", with: "L")
}

extension Date {
    /// "tomorrow", "in 3 days" / "jutro", "za 3 dni": relative to now, in the app's language.
    var relativeInAppLanguage: String {
        formatted(Date.RelativeFormatStyle(presentation: .named, locale: AppLanguage.current.locale))
    }
}

enum PolishPlural {
    /// 1 → one; 2–4, 22–24, … (not 12–14) → few; everything else → many.
    static func form(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let a = abs(n)
        if a == 1 { return one }
        let last = a % 10, lastTwo = a % 100
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return few }
        return many
    }
}
