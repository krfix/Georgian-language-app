import Foundation
import Observation

/// The learner's progress, kept on the phone in UserDefaults ("letterBoxes").
@Observable
final class ProgressStore {
    static let key = "letterBoxes"

    private(set) var letters: LetterProgress

    init() {
        let saved = UserDefaults.standard.dictionary(forKey: Self.key) as? [String: Int] ?? [:]
        letters = LetterProgress(boxes: saved)
    }

    func record(_ char: String, correct: Bool) {
        letters.record(char, correct: correct)
        UserDefaults.standard.set(letters.boxes, forKey: Self.key)
    }

    func reset() {
        letters = LetterProgress()
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}
