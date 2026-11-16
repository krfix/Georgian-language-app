import Foundation

// Automatic tests for everything that decides things without a screen: the course content,
// the exercises made from it, answer checking, the lesson session, spaced repetition, XP,
// streaks, levels, achievements, the daily challenge and the learning path.
// Built and run by .github/workflows/build-ipa.yml:
//   xcrun swiftc Georgian/Curriculum/*.swift Georgian/Engine/*.swift tools/Tests/main.swift
// Those files can't use SwiftUI, UIKit or SwiftData.

var failures = 0
var checks = 0

func check<T: Equatable>(_ label: String, _ got: T, _ want: T, line: Int = #line) {
    checks += 1
    if got != want {
        failures += 1
        print("FAIL [line \(line)] \(label): got \(got), want \(want)")
    }
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let dataDir = root.appendingPathComponent("Georgian/Resources/Curriculum")
let course: Curriculum = {
    do {
        return try Curriculum.load(from: dataDir)
    } catch {
        print("FAIL could not load the course: \(error)")
        exit(1)
    }
}()

func isGeorgianLetter(_ s: Unicode.Scalar) -> Bool { (0x10D0...0x10F0).contains(s.value) }

// MARK: Content

check("33 letters", course.letters.count, 33)
check("letters in alphabetical order", course.letters.map(\.char), course.letters.map(\.char).sorted())
check("no Latin spelling twice", Set(course.letters.map(\.latin)).count, 33)
check("5 modules", course.modules.count, 5)
check("at least 50 lessons", course.lessons.count >= 50, true)
check("lesson ids unique", Set(course.lessons.map(\.id)).count, course.lessons.count)
check("word ids unique", Set(course.words.map(\.id)).count, course.words.count)
check("at least 150 words and phrases", course.words.count >= 150, true)
var badLatin: [String] = []
for w in course.words where course.latin(w.ka) != w.lat { badLatin.append(w.ka) }
for w in course.words where course.latin(w.example.ka) != w.example.lat { badLatin.append(w.example.ka) }
check("every Latin spelling matches its Georgian", badLatin, [])
var badScript: [String] = []
for w in course.words {
    let letters = w.ka.unicodeScalars.filter { CharacterSet.letters.contains($0) }
    if letters.isEmpty || !letters.allSatisfy(isGeorgianLetter) { badScript.append(w.id) }
}
check("words written in Mkhedruli only", badScript, [])
check("every word has an example", course.words.filter { $0.example.ka.isEmpty || $0.example.en.isEmpty }.map(\.id), [])
check("every category is used", Set(course.words.map(\.category)).isSubset(of: Set(course.categories.map(\.id))), true)
var missingWords: [String] = []
for l in course.lessons { for id in l.words ?? [] where course.word(id) == nil { missingWords.append("\(l.id):\(id)") } }
check("every lesson word exists", missingWords, [])
check("ქ is k (with air)", course.letter("ქ")?.latin, "k")
check("კ is k' (tight)", course.letter("კ")?.latin, "k'")
check("Latin of თბილისი", course.latin("თბილისი"), "tbilisi")
check("Latin of წყალი", course.latin("წყალი"), "ts'q'ali")
check("item of a letter", course.item("letter-ა")?.latin, "a")
check("item of a word", course.item("w-gamarjoba")?.english, "hello")
check("look-alikes of კ", Set(course.lookalikes(of: "კ")), Set(["ქ", "ყ"]))
check("letters taught through a2", course.lettersTaught(through: "a2").count, 9)

// MARK: Exercises for every lesson

let builder = ExerciseBuilder(curriculum: course)
var problems: [String] = []
for lesson in course.lessons {
    for seed in 0..<5 {
        var rng = SeededGenerator(seed: UInt64(seed))
        let exercises = builder.exercises(for: lesson, using: &rng)
        let graded = exercises.filter(\.isGraded)
        if graded.count < 4 { problems.append("\(lesson.id): only \(graded.count) graded") }
        if Set(exercises.map(\.id)).count != exercises.count { problems.append("\(lesson.id): ids repeat") }
        for ex in exercises {
            switch ex.content {
            case .choice(let c):
                if c.options.count < 2 { problems.append("\(ex.id): \(c.options.count) options") }
                if Set(c.options.map(\.text)).count != c.options.count { problems.append("\(ex.id): options repeat \(c.options.map(\.text))") }
                if !c.options.contains(where: { $0.id == c.answer }) { problems.append("\(ex.id): answer not among options") }
            case .tiles(let t):
                var bank = t.bank
                for a in t.answer {
                    if let i = bank.firstIndex(of: a) { bank.remove(at: i) } else { problems.append("\(ex.id): tile \(a) missing") }
                }
            case .matching(let pairs):
                if pairs.count < 2 { problems.append("\(ex.id): \(pairs.count) pairs") }
                if Set(pairs.map(\.other)).count != pairs.count { problems.append("\(ex.id): two pairs share an answer") }
            case .dialogue(let d):
                if d.options[d.answer] != d.line.ka { problems.append("\(ex.id): dialogue answer") }
            case .typing(let t):
                if t.accepted.isEmpty { problems.append("\(ex.id): no accepted answers") }
            default: break
            }
        }
    }
}
check("every lesson makes sound exercises", problems, [])
var r1 = SeededGenerator(seed: 9), r2 = SeededGenerator(seed: 9)
check("same seed, same lesson", builder.exercises(for: course.lessons[3], using: &r1).map(\.id),
      builder.exercises(for: course.lessons[3], using: &r2).map(\.id))
var rl = SeededGenerator(seed: 1)
let first = builder.exercises(for: course.lessons[0], using: &rl)
check("lesson 1 starts by teaching ა", first.first?.kind, .teachLetter)
check("lesson 1 teaches five letters", first.filter { $0.kind == .teachLetter }.count, 5)
check("no listening without audio", first.contains { $0.kind == .listening }, false)
let withAudio = ExerciseBuilder(curriculum: course, hasAudio: { _ in true })
var ra = SeededGenerator(seed: 1)
check("listening when audio exists", withAudio.exercises(for: course.lesson("v1")!, using: &ra).contains { $0.kind == .listening }, true)
var rv = SeededGenerator(seed: 2)
let vocab = builder.exercises(for: course.lesson("v7")!, using: &rv)
for kind in [ExerciseKind.teachWord, .multipleChoice, .matching, .translation, .sentenceBuilder] {
    check("a vocabulary lesson has \(kind)", vocab.contains { $0.kind == kind }, true)
}
var rc = SeededGenerator(seed: 2)
check("a conversation has dialogue turns", builder.exercises(for: course.lesson("c1")!, using: &rc).filter { $0.kind == .dialogue }.count, 5)
var rr = SeededGenerator(seed: 3)
let review = builder.review([.word(course.word("w-gamarjoba")!), .letter(course.letter("ღ")!), .word(course.word("w-madloba")!)], using: &rr)
check("review makes one exercise per item", review.count, 3)
check("review exercises carry their item", review.map(\.itemID), ["w-gamarjoba", "letter-ღ", "w-madloba"])
var rd = SeededGenerator(seed: 4)
let dl = builder.distractorLetters(for: course.letter("კ")!, among: course.letters, using: &rd).map(\.char)
check("კ's wrong answers start with its look-alikes", Set(dl.prefix(2)), Set(["ქ", "ყ"]))

// MARK: Checking answers

check("plain: case and punctuation", AnswerEvaluator.plain("Hello!"), "hello")
check("plain: leading the", AnswerEvaluator.plain("The bill, please"), "bill please")
check("plain: curly apostrophe", AnswerEvaluator.plain("you’re welcome"), "you're welcome")
check("typed exact", AnswerEvaluator.typed("hello", accepted: ["hello"]), .correct)
check("typed alternative", AnswerEvaluator.typed("Hi", accepted: AnswerEvaluator.acceptedEnglish(for: course.word("w-gamarjoba")!)), .correct)
check("typed small typo", AnswerEvaluator.typed("helo", accepted: ["hello"]), .almost)
check("typed wrong", AnswerEvaluator.typed("goodbye", accepted: ["hello"]), .wrong)
check("typed empty", AnswerEvaluator.typed("  ", accepted: ["hello"]), .wrong)
check("no typo allowed in short words", AnswerEvaluator.typed("na", accepted: ["no"]), .wrong)
check("brackets optional", AnswerEvaluator.typed("thank you", accepted: AnswerEvaluator.acceptedEnglish(for: course.word("w-gmadlobt")!)), .correct)
check("either meaning of კვირა", AnswerEvaluator.typed("Sunday", accepted: AnswerEvaluator.acceptedEnglish(for: course.word("w-kvira")!)), .correct)
check("distance", AnswerEvaluator.distance("kitten", "sitting"), 3)
let choiceEx = first.first { if case .choice = $0.content { return true } else { return false } }!
if case .choice(let c) = choiceEx.content {
    check("right choice", AnswerEvaluator.evaluate(choiceEx, .choice(c.answer)).verdict, .correct)
    check("wrong choice", AnswerEvaluator.evaluate(choiceEx, .choice((c.answer + 1) % c.options.count)).verdict, .wrong)
}
let tilesEx = vocab.first { $0.kind == .sentenceBuilder }!
if case .tiles(let t) = tilesEx.content {
    check("right tiles", AnswerEvaluator.evaluate(tilesEx, .tiles(t.answer)).verdict, .correct)
    check("tiles in the wrong order", AnswerEvaluator.evaluate(tilesEx, .tiles(t.answer.reversed())).verdict, .wrong)
}

// MARK: Lesson session

var session = LessonSession(exercises: Array(first.prefix(4)))
check("session starts at 0", session.progress, 0)
while let ex = session.current {
    let wrongFirst = ex.isGraded && !ex.id.hasSuffix("+") && session.firstTry.isEmpty
    session.record(Evaluation(verdict: wrongFirst ? .wrong : .correct, correctAnswer: "x", explanation: nil), given: "y")
    session.advance()
}
check("a wrong answer comes back once", session.queue.count, 5)
check("session finished", session.isFinished, true)
check("first try counts the mistake", session.summary.correctFirstTry, session.summary.graded - 1)
check("one mistake listed", session.mistakes.count, 1)
check("not perfect", session.summary.isPerfect, false)
check("XP for a lesson", XPRules.lesson(SessionSummary(graded: 10, correctFirstTry: 8, mistakes: 2)), 18)
check("XP for a perfect lesson", XPRules.lesson(SessionSummary(graded: 10, correctFirstTry: 10, mistakes: 0)), 25)
check("accuracy", SessionSummary(graded: 4, correctFirstTry: 3, mistakes: 1).accuracy, 0.75)

// MARK: Spaced repetition

var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(identifier: "UTC")!
let now = Date(timeIntervalSince1970: 1_800_000_000)
var s = ReviewState(due: now)
s = SpacedRepetition.schedule(s, .good, now: now, calendar: utc)
check("first right answer: back tomorrow", s.interval, 1)
s = SpacedRepetition.schedule(s, .good, now: now, calendar: utc)
check("second: in 3 days", s.interval, 3)
check("learned after two", s.isLearned, true)
s = SpacedRepetition.schedule(s, .good, now: now, calendar: utc)
check("third: further out", s.interval, 8)
let afterMiss = SpacedRepetition.schedule(s, .again, now: now, calendar: utc)
check("a miss starts over", afterMiss.repetitions, 0)
check("a miss comes back in minutes", afterMiss.due.timeIntervalSince(now), 600)
check("a miss lowers the ease", afterMiss.ease < s.ease, true)
check("due now", SpacedRepetition.isDue(afterMiss, now: now.addingTimeInterval(601)), true)
check("not due yet", SpacedRepetition.isDue(s, now: now), false)
var hard = ReviewState(due: now)
for _ in 0..<2 { hard = SpacedRepetition.schedule(hard, .again, now: now, calendar: utc) }
check("two misses: difficult", hard.isDifficult, true)
check("ease never below 1.3", (0..<20).reduce(ReviewState(due: now)) { st, _ in SpacedRepetition.schedule(st, .again, now: now, calendar: utc) }.ease, 1.3)
check("grade from verdict", ReviewGrade(.almost), .hard)

// MARK: Days, streaks, levels

check("day key", DayKey.of(now, calendar: utc), "2027-01-15")
check("day before", DayKey.adding(-1, to: "2026-03-01", calendar: utc), "2026-02-28")
check("last 3 days", DayKey.lastDays(3, endingOn: "2026-01-01", calendar: utc), ["2025-12-30", "2025-12-31", "2026-01-01"])
let days: Set<String> = ["2026-11-10", "2026-11-11", "2026-11-12", "2026-11-14", "2026-11-15"]
check("streak today", Streak.current(activeDays: days, today: "2026-11-15", calendar: utc), 2)
check("streak still alive the next morning", Streak.current(activeDays: days, today: "2026-11-16", calendar: utc), 2)
check("streak broken", Streak.current(activeDays: days, today: "2026-11-17", calendar: utc), 0)
check("longest streak", Streak.longest(activeDays: days, calendar: utc), 3)
check("level 1 at 0 XP", LearnerLevel.level(forXP: 0), 1)
check("level 2 at 50 XP", LearnerLevel.level(forXP: 50), 2)
check("level 3 at 120 XP", LearnerLevel.level(forXP: 120), 3)
check("half way to level 2", LearnerLevel.progress(forXP: 25), 0.5)

// MARK: Achievements and challenge

var snap = ProgressSnapshot()
snap.today = "2026-11-15"
let before = snap
snap.lessonsCompleted = ["a1"]
snap.totalXP = 120
snap.perfectLessons = 1
let unlocked = Achievement.newlyUnlocked(before: before, after: snap, alreadyRecorded: []).map(\.id)
check("first lesson, perfect and 100 XP unlocked", Set(unlocked), Set(["first-lesson", "perfect", "xp-100"]))
check("already recorded ones aren't repeated", Achievement.newlyUnlocked(before: before, after: snap, alreadyRecorded: ["first-lesson", "perfect", "xp-100"]).isEmpty, true)
check("achievement ids unique", Set(Achievement.all.map(\.id)).count, Achievement.all.count)
check("challenge is the same all day", DailyChallenge.of(day: "2026-11-15", dailyGoal: 20), DailyChallenge.of(day: "2026-11-15", dailyGoal: 20))
let kinds = Set((1...28).map { DailyChallenge.of(day: String(format: "2026-02-%02d", $0), dailyGoal: 20).kind })
check("challenges vary over a month", kinds.count >= 3, true)

// MARK: Learning path

let ids = ["a", "b", "c", "d"]
check("beginner: first is current, rest locked", CourseProgress.states(lessonIDs: ids, completed: []),
      ["a": .current, "b": .locked, "c": .locked, "d": .locked])
check("after the first", CourseProgress.states(lessonIDs: ids, completed: ["a"]),
      ["a": .completed, "b": .current, "c": .locked, "d": .locked])
check("can read: starts later, earlier ones open", CourseProgress.states(lessonIDs: ids, completed: [], startIndex: 2, openBefore: 2),
      ["a": .available, "b": .available, "c": .current, "d": .locked])
check("knows some letters: open ahead", CourseProgress.states(lessonIDs: ids, completed: [], startIndex: 0, openBefore: 3),
      ["a": .current, "b": .available, "c": .available, "d": .locked])
check("next lesson", CourseProgress.next(lessonIDs: ids, completed: ["a", "b"]), "c")
check("all done", CourseProgress.next(lessonIDs: ids, completed: Set(ids)), nil)

print("\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
