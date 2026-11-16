import Foundation

/// The whole course, loaded once and looked up by id.
final class Curriculum {
    let courseID: String
    let version: Int
    let title: String
    let modules: [CourseModule]
    let letters: [LetterInfo]
    let lookalikes: [[String]]
    let categories: [WordCategory]
    let words: [Word]

    /// Every lesson in course order.
    let lessons: [Lesson]
    private let wordsByID: [String: Word]
    private let lettersByChar: [String: LetterInfo]
    private let moduleByLesson: [String: CourseModule]
    private let lessonByID: [String: Lesson]

    init(course: CourseFile, letters: LettersFile, vocabulary: VocabularyFile) {
        courseID = course.id
        version = course.version
        title = course.title
        modules = course.modules
        self.letters = letters.letters
        lookalikes = letters.lookalikes
        categories = vocabulary.categories
        words = vocabulary.words
        lessons = course.modules.flatMap(\.lessons)
        wordsByID = Dictionary(vocabulary.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        lettersByChar = Dictionary(letters.letters.map { ($0.char, $0) }, uniquingKeysWith: { a, _ in a })
        var byLesson: [String: CourseModule] = [:]
        for m in course.modules { for l in m.lessons { byLesson[l.id] = m } }
        moduleByLesson = byLesson
        lessonByID = Dictionary(lessons.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    enum LoadError: Error { case missing(String) }

    /// Reads the three JSON files from a folder (the tests) or from the app bundle.
    static func load(from directory: URL? = nil, bundle: Bundle = .main) throws -> Curriculum {
        func url(_ name: String) throws -> URL {
            if let directory { return directory.appendingPathComponent(name + ".json") }
            if let u = bundle.url(forResource: name, withExtension: "json") { return u }
            if let u = bundle.url(forResource: name, withExtension: "json", subdirectory: "Curriculum") { return u }
            throw LoadError.missing(name)
        }
        let decoder = JSONDecoder()
        let course = try decoder.decode(CourseFile.self, from: Data(contentsOf: url("course")))
        let letters = try decoder.decode(LettersFile.self, from: Data(contentsOf: url("letters")))
        let vocabulary = try decoder.decode(VocabularyFile.self, from: Data(contentsOf: url("vocabulary")))
        return Curriculum(course: course, letters: letters, vocabulary: vocabulary)
    }

    func word(_ id: String) -> Word? { wordsByID[id] }
    func letter(_ char: String) -> LetterInfo? { lettersByChar[char] }
    func lesson(_ id: String) -> Lesson? { lessonByID[id] }
    func module(of lessonID: String) -> CourseModule? { moduleByLesson[lessonID] }
    func category(_ id: String) -> WordCategory? { categories.first { $0.id == id } }

    func words(in lesson: Lesson) -> [Word] { (lesson.words ?? []).compactMap(word) }

    /// Letters that people mix up with this one.
    func lookalikes(of char: String) -> [String] {
        var out: [String] = []
        for group in lookalikes where group.contains(char) {
            for c in group where c != char && !out.contains(c) { out.append(c) }
        }
        return out
    }

    /// Latin spelling of any Georgian text, letter by letter (national system).
    func latin(_ georgian: String) -> String {
        georgian.map { ch -> String in
            let s = String(ch)
            return lettersByChar[s]?.latin ?? s
        }.joined()
    }

    /// The letters taught before (and in) a lesson, in order.
    func lettersTaught(through lessonID: String) -> [LetterInfo] {
        var out: [LetterInfo] = []
        for l in lessons {
            for c in l.letters ?? [] { if let info = letter(c) { out.append(info) } }
            if l.id == lessonID { break }
        }
        return out
    }

    /// A word's or letter's display data for review and the vocabulary screens.
    func item(_ itemID: String) -> StudyItem? {
        if itemID.hasPrefix("letter-") {
            return letter(String(itemID.dropFirst(7))).map(StudyItem.letter)
        }
        return word(itemID).map(StudyItem.word)
    }
}

/// Something the learner studies and reviews: a letter or a word.
enum StudyItem: Hashable, Identifiable {
    case letter(LetterInfo)
    case word(Word)

    var id: String {
        switch self {
        case .letter(let l): return l.itemID
        case .word(let w): return w.id
        }
    }
    var georgian: String {
        switch self {
        case .letter(let l): return l.char
        case .word(let w): return w.ka
        }
    }
    var latin: String {
        switch self {
        case .letter(let l): return l.latin
        case .word(let w): return w.lat
        }
    }
    var english: String {
        switch self {
        case .letter(let l): return "the letter \(l.name)"
        case .word(let w): return w.en
        }
    }
}
