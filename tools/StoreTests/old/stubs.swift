import Foundation

// The two app types the old Models.swift files mention (in computed properties only, so
// nothing about them is saved). Just enough for the old models to compile on their own.
struct ReviewState {
    var ease: Double
    var interval: Int
    var repetitions: Int
    var due: Date
    var lapses: Int
}

enum StartingLevel: String {
    case beginner, someLetters, canRead
}
