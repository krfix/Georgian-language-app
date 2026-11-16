import Foundation

// Automatic tests for the parts of the app that decide things: the alphabet's data and the
// letter quiz (which letters are asked, how often, and the wrong answers offered).
// Built and run by .github/workflows/build-ipa.yml:
//   xcrun swiftc Georgian/Models/Letter.swift Georgian/Services/Quiz.swift tools/Tests/main.swift
// A test that needs another app file means adding it to that list (in the workflow too).
// Those files can't use SwiftUI or UIKit.

var failures = 0
var checks = 0

func check<T: Equatable>(_ label: String, _ got: T, _ want: T, line: Int = #line) {
    checks += 1
    if got != want {
        failures += 1
        print("FAIL [line \(line)] \(label): got \(got), want \(want)")
    }
}

// MARK: The alphabet

let letters = Alphabet.letters
check("alphabet: 33 letters", letters.count, 33)
check("alphabet: no letter twice", Set(letters.map(\.char)).count, 33)
check("alphabet: no Latin spelling twice", Set(letters.map(\.latin)).count, 33)
check("alphabet: one character each", letters.allSatisfy { $0.char.count == 1 }, true)
check("alphabet: in Unicode order (= alphabetical for Mkhedruli)",
      letters.map { $0.char.unicodeScalars.first!.value }, letters.map { $0.char.unicodeScalars.first!.value }.sorted())
for l in letters {
    check("word for \(l.char) starts with it", l.word.hasPrefix(l.char), true)
    check("word for \(l.char) is all Georgian", l.word.unicodeScalars.allSatisfy { (0x10D0...0x10FF).contains($0.value) }, true)
}
let allLookalikes = Alphabet.lookalikes.flatMap { $0 }
check("look-alikes are real letters", allLookalikes.allSatisfy { Alphabet.letter($0) != nil }, true)

// MARK: Progress

var p = LetterProgress()
check("progress: new letter in box 0", p.box("ა"), 0)
check("progress: not seen", p.isSeen("ა"), false)
p.record("ა", correct: true)
check("progress: right answer moves up", p.box("ა"), 1)
check("progress: now seen", p.isSeen("ა"), true)
for _ in 0..<10 { p.record("ა", correct: true) }
check("progress: stops at the top box", p.box("ა"), LetterProgress.top)
check("progress: known", p.knownCount, 1)
p.record("ა", correct: false)
check("progress: wrong answer goes back to 0", p.box("ა"), 0)
check("progress: missed letter still seen", p.isSeen("ა"), true)
check("progress: no longer known", p.knownCount, 0)

// MARK: Which letters are asked

check("pool: a beginner starts with the first five", Quiz.pool(LetterProgress()).map(\.char), ["ა", "ბ", "გ", "დ", "ე"])
var some = LetterProgress()
for c in ["ა", "ბ"] { for _ in 0..<LetterProgress.top { some.record(c, correct: true) } }
some.record("გ", correct: true)
check("pool: known letters stay, new ones join to keep five learning",
      Quiz.pool(some).map(\.char), ["ა", "ბ", "გ", "დ", "ე", "ვ", "ზ"])
var all = LetterProgress()
for l in letters { for _ in 0..<LetterProgress.top { all.record(l.char, correct: true) } }
check("pool: everything known asks the whole alphabet", Quiz.pool(all).count, 33)
check("weight: box 0 weighs most", Quiz.weight(0), 25)
check("weight: known weighs least", Quiz.weight(LetterProgress.top), 1)

var rng = SeededGenerator(seed: 1)
var last: String? = nil
var repeats = 0
var asked: [String: Int] = [:]
for _ in 0..<2000 {
    let l = Quiz.pick(some, after: last, using: &rng)
    if l.char == last { repeats += 1 }
    asked[l.char, default: 0] += 1
    last = l.char
}
check("pick: never the same letter twice in a row", repeats, 0)
check("pick: only letters from the pool", Set(asked.keys).isSubset(of: Set(Quiz.pool(some).map(\.char))), true)
check("pick: a new letter comes up more than a known one", asked["დ", default: 0] > asked["ა", default: 0] * 3, true)

// MARK: Wrong answers

var badOptions: [String] = []
for seed in 0..<50 {
    var r = SeededGenerator(seed: UInt64(seed))
    for l in letters {
        let o = Quiz.options(for: l, using: &r)
        if o.count != 4 || !o.contains(l) || Set(o.map(\.latin)).count != 4 { badOptions.append(l.char) }
    }
}
check("options: always four, all different, the answer among them", badOptions, [])
var rk = SeededGenerator(seed: 7)
let forK = Quiz.options(for: Alphabet.letter("კ")!, using: &rk).map(\.char)
check("options: კ is offered its look-alikes ქ and ყ", Set(["ქ", "ყ"]).isSubset(of: Set(forK)), true)

var rq = SeededGenerator(seed: 3)
check("question: a beginner is asked letter → Latin", Quiz.question(LetterProgress(), after: nil, using: &rq).direction, .toLatin)

print("\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
