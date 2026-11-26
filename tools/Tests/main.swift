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
// Every word the app shows is in the Words tab (KART #5): the course's words or "more".
let allWordKa = Set((course.words + course.moreWords).map(\.ka))
check("over 500 more words", course.moreWords.count > 500, true)
check("more word ids unique and apart", Set((course.words + course.moreWords).map(\.id)).count, course.words.count + course.moreWords.count)
check("every letter's example word is in Words", course.letters.map(\.word).filter { !allWordKa.contains($0) }, [])
check("გული (heart) is in Words", course.moreWords.first { $0.ka == "გული" }?.en, "heart")
check("a more word is found by id", course.word("x-guli")?.ka, "გული")
check("more words have examples", course.moreWords.filter { $0.example.ka.isEmpty || $0.example.en.isEmpty }.map(\.id), [])
var badMoreLatin: [String] = []
for w in course.moreWords where course.latin(w.ka) != w.lat || course.latin(w.example.ka) != w.example.lat { badMoreLatin.append(w.ka) }
check("more words' Latin matches", badMoreLatin, [])
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
check("not known after two", s.isLearned, false)
s = SpacedRepetition.schedule(s, .good, now: now, calendar: utc)
check("third: further out", s.interval, 8)
check("not known after three", s.isLearned, false)
let fourth = SpacedRepetition.schedule(s, .good, now: now, calendar: utc)
check("known after four in a row", fourth.isLearned, true)
check("fourth: about three weeks", fourth.interval, 20)
check("a miss: not known any more", SpacedRepetition.schedule(fourth, .again, now: now, calendar: utc).isLearned, false)
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

// MARK: Words seen, new and known (KART #20)

let firstLessons = Array(course.lessons.prefix(3))
check("every lesson lists the words it shows", course.lessons.allSatisfy { !($0.seen ?? []).isEmpty }, true)
check("seen ids are words", course.lessons.flatMap { $0.seen ?? [] }.allSatisfy { course.word($0) != nil }, true)
check("a lesson's own words are seen in it", course.lessons.allSatisfy { l in (l.words ?? []).allSatisfy { (l.seen ?? []).contains($0) } }, true)
check("nothing seen before a lesson is done", WordProgress.seen(lessons: course.lessons, completed: []).isEmpty, true)
let seenA1 = WordProgress.seen(lessons: course.lessons, completed: [firstLessons[0].id])
check("a finished lesson's words are seen", Set(seenA1.keys), Set(firstLessons[0].seen ?? []))
check("seen in that lesson", seenA1.values.allSatisfy { $0 == firstLessons[0].id }, true)
let firstOf = WordProgress.firstLesson(lessons: course.lessons)
check("first lesson of a word in two lessons is the earlier",
      course.lessons.allSatisfy { l in (l.seen ?? []).allSatisfy { id in
          let i = course.lessons.firstIndex { $0.id == firstOf[id] } ?? .max
          return i <= course.lessons.firstIndex(of: l)! } }, true)
let a2 = firstLessons[1]
let newInA2 = WordProgress.newWords(in: a2, before: Set(seenA1.keys))
check("new words: none already met", newInA2.allSatisfy { seenA1[$0] == nil }, true)
check("new words: all the rest", newInA2.count, (a2.seen ?? []).filter { seenA1[$0] == nil }.count)
check("doing a lesson again: nothing new", WordProgress.newWords(in: a2, before: Set(a2.seen ?? [])), [])
var three = ReviewState(due: now)
for _ in 0..<3 { three = SpacedRepetition.schedule(three, .good, now: now, calendar: utc) }
let four = SpacedRepetition.schedule(three, .good, now: now, calendar: utc)
check("newly known after a warm-up", WordProgress.newlyKnown(["a", "b"], before: ["a": three, "b": four], after: ["a": four, "b": four]), ["a"])
check("warm-up items not known stay out", WordProgress.newlyKnown(["a"], before: ["a": three], after: ["a": three]), [])

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
snap.lessonsCompleted = ["a1", "c1"]
snap.totalXP = 120
snap.perfectLessons = 1
let unlocked = Achievement.newlyUnlocked(before: before, after: snap, alreadyRecorded: []).map(\.id)
check("first lesson, perfect and the café unlocked", Set(unlocked), Set(["first-lesson", "perfect", "cafe"]))
check("already recorded ones aren't repeated", Achievement.newlyUnlocked(before: before, after: snap, alreadyRecorded: ["first-lesson", "perfect", "cafe"]).isEmpty, true)
check("achievement ids unique", Set(Achievement.all.map(\.id)).count, Achievement.all.count)
check("challenge is the same all day", DailyChallenge.of(day: "2026-11-15", dailyGoal: 20), DailyChallenge.of(day: "2026-11-15", dailyGoal: 20))
let kinds = Set((1...28).map { DailyChallenge.of(day: String(format: "2026-02-%02d", $0), dailyGoal: 20).kind })
check("challenges vary over a month", kinds.count >= 3, true)


// MARK: Phrasebook

let pb = course.phrasebook
check("phrasebook has 11 situations", pb.categories.count, 11)
check("phrasebook has at least 250 phrases", pb.phrases.count >= 250, true)
check("phrasebook has at least 10 dialogues", pb.dialogues.count >= 10, true)
check("phrase ids unique", Set(pb.phrases.map(\.id)).count, pb.phrases.count)
check("phrase ids start pb-", pb.phrases.filter { !Phrasebook.isPhraseID($0.id) }.map(\.id), [])
check("phrase ids don't clash with course words", pb.phrases.filter { p in course.words.contains { $0.id == p.id } }.map(\.id), [])
var pbProblems: [String] = []
for p in pb.phrases {
    if course.latin(p.ka) != p.lat { pbProblems.append("\(p.id): Latin") }
    for v in (p.variants ?? []) + (p.replies ?? []) where course.latin(v.ka) != v.lat { pbProblems.append("\(p.id): Latin of \(v.ka)") }
    if p.sound.isEmpty { pbProblems.append("\(p.id): no sound guide") }
    guard let c = pb.category(p.category) else { pbProblems.append("\(p.id): category"); continue }
    if c.sub(p.sub) == nil { pbProblems.append("\(p.id): subcategory \(p.sub)") }
    if p.keywords.isEmpty { pbProblems.append("\(p.id): keywords") }
    if p.urgent != c.isEmergency { pbProblems.append("\(p.id): urgent flag") }
    for w in p.words ?? [] where course.word(w) == nil { pbProblems.append("\(p.id): linked word \(w)") }
    for g in p.grammar ?? [] where course.lesson(g.lesson)?.kind != .grammar { pbProblems.append("\(p.id): grammar \(g.lesson)") }
    let letters = p.ka.unicodeScalars.filter { CharacterSet.letters.contains($0) }
    if letters.isEmpty || !letters.allSatisfy(isGeorgianLetter) { pbProblems.append("\(p.id): not Mkhedruli") }
}
for c in pb.categories where pb.phrases(in: c.id).count < 5 { pbProblems.append("\(c.id): too few phrases") }
check("every phrase is sound", pbProblems, [])
check("sound guide of გამარჯობა", pb.phrase("pb-gamarjoba")?.sound, "gah-mahr-joh-bah")
check("a phrase is a word for review", course.word("pb-ver-gavige")?.ka, "ვერ გავიგე.")
check("a phrase is a study item", course.item("pb-ver-gavige")?.english, "I didn't understand.")
check("emergency phrases are urgent", pb.phrases(in: "emergency").allSatisfy(\.urgent), true)
check("112 is in the emergency phrases", pb.phrases(in: "emergency").contains { $0.ka.contains("112") }, true)

// Dialogues, and practising either side.
var dProblems: [String] = []
for d in pb.dialogues {
    if d.roles.count != 2 { dProblems.append("\(d.id): roles") }
    if pb.category(d.category) == nil { dProblems.append("\(d.id): category") }
    for role in 0...1 {
        let lesson = pb.practiceLesson(d, role: role)
        let mine = d.lines.filter { $0.who == role }.count
        for seed in 0..<3 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let ex = builder.exercises(for: lesson, using: &rng)
            let turns = ex.compactMap { e -> DialogueTurn? in if case .dialogue(let t) = e.content { return t } else { return nil } }
            if turns.count != mine { dProblems.append("\(d.id) as \(role): \(turns.count) turns, want \(mine)") }
            for t in turns {
                if t.options.count != 3 { dProblems.append("\(d.id) as \(role): \(t.options.count) options") }
                if Set(t.options).count != t.options.count { dProblems.append("\(d.id) as \(role): options repeat") }
                if t.options[t.answer] != t.line.ka { dProblems.append("\(d.id) as \(role): answer") }
            }
            if Set(ex.map(\.id)).count != ex.count { dProblems.append("\(d.id) as \(role): ids repeat") }
        }
    }
}
check("every dialogue can be practised from both sides", dProblems, [])

// Phrases in review: mixed with other phrases, never typed in English.
var rph = SeededGenerator(seed: 4)
let phraseItems = ["pb-es-ra-ghirs", "pb-ver-gavige", "pb-khortss-ar-vcham", "pb-ak-gamicheret-tu-sheidzleba"].compactMap(course.item)
check("four phrases as review items", phraseItems.count, 4)
let phraseReview = builder.review(phraseItems, using: &rph)
check("a review exercise per phrase", phraseReview.count, 4)
check("phrase reviews keep their item", phraseReview.map(\.itemID), phraseItems.map(\.id) as [String?])
check("no English typing for phrases", phraseReview.contains { $0.kind == .translation }, false)
var reviewOptions: [String] = []
for e in phraseReview { if case .choice(let c) = e.content { reviewOptions += c.options.map(\.text) } }
check("phrase distractors are phrases", reviewOptions.allSatisfy { o in pb.phrases.contains { $0.en == o || $0.ka == o } }, true)

// Search: the real-life scenarios, and the ways people type.
func topIDs(_ q: String, _ n: Int = 3) -> [String] { pb.search.top(q, n).map(\.id) }
func finds(_ q: String, _ id: String, within n: Int = 3, line: Int = #line) {
    check("search \"\(q)\" finds \(id)", topIDs(q, n).contains(id), true, line: line)
}
finds("stop here", "pb-ak-gamicheret-tu-sheidzleba")               // a tourist asks a taxi driver to stop
finds("taxi stop", "pb-ak-gamicheret-tu-sheidzleba")
finds("how much is this", "pb-es-ra-ghirs")                         // a price at the bazaar
finds("price", "pb-es-ra-ghirs", within: 4)
finds("I don't eat meat", "pb-khortss-ar-vcham")                    // telling a waiter
finds("vegetarian", "pb-khortss-ar-vcham")
finds("where is the nearest pharmacy", "pb-ak-akhlos-aptiaki-aris")  // finding a pharmacy
finds("pharmacy", "pb-aptiaki-sad-aris")
finds("my name is", "pb-me-joni-mkvia")                             // meeting a neighbour
finds("neighbour", "pb-akhali-mezobeli-var")
finds("neighbor", "pb-akhali-mezobeli-var")
finds("gym membership", "pb-abonementi-ra-ghirs")                   // a gym receptionist
finds("I don't understand", "pb-ver-gavige")
finds("expensive", "pb-dzalian-dzviria")
finds("pharmcy", "pb-aptiaki-sad-aris")                             // a typo
finds("chemist", "pb-aptiaki-sad-aris")                             // a synonym
finds("gamarjoba", "pb-gamarjoba", within: 1)                       // Latin letters
finds("გამარჯობა", "pb-gamarjoba", within: 1)                       // Georgian
finds("ვერ გავ", "pb-ver-gavige", within: 1)                        // the start of a Georgian phrase
check("\"taxi\" starts with transport", pb.search.top("taxi", 1).first?.category, "transport")
check("\"cab\" starts with transport", pb.search.top("cab", 1).first?.category, "transport")
let waterCategories = Set(pb.search.search("water", limit: 12).phrases.map(\.category))
check("\"water\" finds phrases in shopping, restaurants and home", waterCategories.isSuperset(of: ["shopping", "food", "home"]), true)
check("\"water\" also finds the course word", pb.search.search("water").words.contains { $0.id == "w-tsqali" }, true)
check("\"heart\" finds გული in Search", pb.search.search("heart").words.contains { $0.id == "x-guli" }, true)
check("\"emergency\" finds the situation", pb.search.search("emergency").categories.first?.id, "emergency")
check("\"taxi\" finds the taxi dialogue", pb.search.search("taxi").dialogues.contains { $0.id == "pd-taxi" }, true)
check("nothing for nonsense", pb.search.search("zzqxw").isEmpty, true)
check("nothing for an empty query", pb.search.search("   ").isEmpty, true)
check("stem of pharmacies", PhraseSearch.stem("pharmacies"), "pharmacy")
check("plain removes apostrophes", PhraseSearch.plain("Ts'q'ali, don't!"), "tsqali dont")

// MARK: Polish (KART #4)

let polish: Curriculum? = try? Curriculum.load(from: dataDir, language: .pl)
check("the Polish course loads", polish != nil, true)
check("Polish more words: same ids", polish?.moreWords.map(\.id), course.moreWords.map(\.id))
check("გული in Polish", polish?.word("x-guli")?.en, "serce")
if let pl = polish {
    check("Polish: same lessons", pl.lessons.map(\.id), course.lessons.map(\.id))
    check("Polish: same words", pl.words.map(\.id), course.words.map(\.id))
    check("Polish: same Georgian", pl.words.map(\.ka), course.words.map(\.ka))
    check("Polish: same phrases", pl.phrasebook.phrases.map(\.id), pb.phrases.map(\.id))
    check("Polish: ხ is like ch in chleb", pl.letter("ხ")?.sound.contains("chleb"), true)
    check("Polish: მამა… a word in Polish", pl.word("w-mama")?.en, "ojciec")
    check("Polish: the sound guide uses Polish spelling", pl.phrasebook.phrase("pb-gamarjoba")?.sound, "ga-mar-dżo-ba")
    var english: [String] = []
    for w in pl.words where w.en == course.word(w.id)?.en && w.en.range(of: "[a-z]{4,}", options: .regularExpression) != nil
        && !["zero", "metro", "lari"].contains(w.en) { english.append(w.id) }
    check("Polish: no word left in English", english, [])
    AppLanguage.use(.pl, save: false)
    func plTop(_ q: String) -> [String] { pl.phrasebook.search.top(q, 3).map(\.id) }
    check("Polish search: apteka", plTop("apteka").contains("pb-aptiaki-sad-aris"), true)
    check("Polish search: taksowka without accents", pl.phrasebook.search.top("taksowka", 1).first?.category, "transport")
    check("Polish search: toaleta", plTop("gdzie jest toaleta").contains("pb-sad-aris-tualeti"), true)
    check("Polish search: rachunek", plTop("rachunek").contains("pb-angarishi-tu-sheidzleba"), true)
    check("Polish search: Georgian still works", plTop("გამარჯობა").first, "pb-gamarjoba")
    let typed = AnswerEvaluator.acceptedEnglish(for: pl.word("p-ver-gavige")!)
    check("Polish answer: without ł", AnswerEvaluator.typed("nie zrozumialem", accepted: typed), .correct)
    check("Polish answer: feminine form", AnswerEvaluator.typed("Nie zrozumiałam", accepted: typed), .correct)
    var rp = SeededGenerator(seed: 7)
    let plLesson = ExerciseBuilder(curriculum: pl).exercises(for: pl.lesson("v6c")!, using: &rp)
    check("Polish: the numbers grammar lesson has notes and exercises", plLesson.filter { $0.kind == .note }.count, 4)
    AppLanguage.use(.en, save: false)
}
// "Why" cards and the new grammar (KART #4).
var ri = SeededGenerator(seed: 3)
check("a vocabulary lesson starts with its why card", builder.exercises(for: course.lesson("v1")!, using: &ri).first?.kind, .note)
check("the past-tense lesson exists", course.lesson("g13")?.notes?.count, 2)
check("13 grammar lessons", course.lessons.filter { $0.kind == .grammar }.count >= 13, true)

// Tappable words: every word of every example, conversation and phrase has an explanation.
check("the glossary loads", course.glossary.count > 700, true)
var noGloss: [String] = []
var glossTexts = course.words.map(\.example.ka) + pb.phrases.map(\.ka) + pb.dialogues.flatMap { $0.lines.map(\.ka) }
for l in course.lessons { glossTexts += l.dialogue?.lines.map(\.ka) ?? [] }
for text in glossTexts {
    for w in Curriculum.wordsForTapping(text) where w.unicodeScalars.contains(where: isGeorgianLetter) && course.gloss(w) == nil {
        noGloss.append(w)
    }
}
check("every word can be tapped", Array(Set(noGloss)).sorted(), [])
check("სახლში comes from სახლი", course.gloss("სახლში,")?.base, "სახლი")
check("Polish glossary", polish?.gloss("გაქვთ?")?.meaning?.contains("pan") ?? false, true)

Localizer.load(table: ["Lesson {0} of {1}": "Lekcja {0} z {1}"])
check("tr fills placeholders", tr("Lesson {0} of {1}", 3, 10), "Lekcja 3 z 10")
check("tr falls back to English", tr("Not in the table"), "Not in the table")
Localizer.load(table: [:])
check("Polish plural 1", PolishPlural.form(1, "słowo", "słowa", "słów"), "słowo")
check("Polish plural 3", PolishPlural.form(3, "słowo", "słowa", "słów"), "słowa")
check("Polish plural 12", PolishPlural.form(12, "słowo", "słowa", "słów"), "słów")
check("Polish plural 22", PolishPlural.form(22, "słowo", "słowa", "słów"), "słowa")
check("Polish plural 25", PolishPlural.form(25, "słowo", "słowa", "słów"), "słów")
check("accents off", withoutAccents("Zażółć gęślą jaźń"), "Zazolc gesla jazn")

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

// MARK: Course stages (playful names instead of exam levels)

check("six stages", CourseStage.all.count, 6)
check("every stage but the first ends a module", CourseStage.all.dropFirst().compactMap(\.moduleID), course.modules.map(\.id))
check("start: just landed", CourseStage.current(modulesCompleted: []).id, 0)
check("alphabet done: sign reader", CourseStage.current(modulesCompleted: ["alphabet"]).id, 1)
check("three parts done", CourseStage.current(modulesCompleted: ["alphabet", "vocabulary", "everyday"]).id, 3)
check("all done: tamada", CourseStage.current(modulesCompleted: Set(course.modules.map(\.id))).id, 5)
check("after the last, nothing", CourseStage.all[5].next, nil)
check("next after the start", CourseStage.all[0].next?.id, 1)

// MARK: Daily reminder: only on days not practised yet (KART #16)

do {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Asia/Tbilisi")!
    let morning = cal.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 9))!
    let evening = cal.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 21))!
    let day = { (d: Date) in cal.component(.day, from: d) }
    let notYet = ReminderPlan.dates(hour: 19, minute: 30, practisedToday: false, days: 14, now: morning, calendar: cal)
    check("reminder: 14 days, from today", notYet.map(day).prefix(2), [26, 27])
    check("reminder: 14 of them", notYet.count, 14)
    check("reminder: at the chosen time", notYet.first.map { "\(cal.component(.hour, from: $0)):\(cal.component(.minute, from: $0))" },
          "19:30")
    let practised = ReminderPlan.dates(hour: 19, minute: 30, practisedToday: true, days: 14, now: morning, calendar: cal)
    check("reminder: practised today, so not today", practised.map(day).first, 27)
    check("reminder: then 13 days", practised.count, 13)
    let late = ReminderPlan.dates(hour: 19, minute: 30, practisedToday: false, days: 14, now: evening, calendar: cal)
    check("reminder: time passed today, so not today", late.map(day).first, 27)
    check("reminder: none when no days", ReminderPlan.dates(hour: 9, minute: 0, practisedToday: false, days: 0, now: morning, calendar: cal), [])
}

// Automatic playback (KART #18): what a lesson says by itself, never giving an answer away.
do {
    func choice(_ kind: ExerciseKind, prompt: String, ka: Bool, options: [String], kaOptions: Bool, answer: Int = 0, audio: String? = nil) -> Exercise {
        Exercise(id: "t", kind: kind, instruction: "", itemID: nil, content: .choice(Choice(
            prompt: prompt, promptIsGeorgian: ka, promptDetail: nil,
            options: options.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element, detail: nil) },
            optionsAreGeorgian: kaOptions, answer: answer, explanation: nil, audioText: audio)))
    }
    let meaning = choice(.multipleChoice, prompt: "წყალი", ka: true, options: ["water", "bread"], kaOptions: false)
    check("auto: a Georgian word to translate is said", AutoSpeech.onShow(meaning), "წყალი")
    let read = choice(.reading, prompt: "წყალი", ka: true, options: ["ts'qali", "puri"], kaOptions: false)
    check("auto: a word to read isn't said first", AutoSpeech.onShow(read), nil)
    check("auto: ...but after Check", AutoSpeech.onCheck(read, given: .choice(1), correct: false), "წყალი")
    let letter = choice(.letterRecognition, prompt: "b", ka: false, options: ["ბ", "პ"], kaOptions: true)
    check("auto: every letter tapped is said", AutoSpeech.onPick(letter, from: .choice(1), to: .choice(1)), "პ")
    check("auto: the right letter after Check", AutoSpeech.onCheck(letter, given: .choice(1), correct: false), "ბ")
    let say = choice(.multipleChoice, prompt: "water", ka: false, options: ["წყალი", "პური"], kaOptions: true)
    check("auto: the Georgian picked is said", AutoSpeech.onPick(say, from: nil, to: .choice(1)), "პური")
    check("auto: wrong pick, the right one after Check", AutoSpeech.onCheck(say, given: .choice(1), correct: false), "წყალი")
    check("auto: right pick, nothing more", AutoSpeech.onCheck(say, given: .choice(0), correct: true), nil)
    let gap = choice(.fillBlank, prompt: "მე ___ მინდა.", ka: true, options: ["წყალი", "პური"], kaOptions: true)
    check("auto: a sentence with a gap isn't said first", AutoSpeech.onShow(gap), nil)
    check("auto: right, nothing after Check", AutoSpeech.onCheck(gap, given: .choice(0), correct: true), nil)
    check("auto: wrong, the whole sentence after Check", AutoSpeech.onCheck(gap, given: .choice(1), correct: false), "მე წყალი მინდა.")
    let missing = choice(.missingLetter, prompt: "წ_ალი", ka: true, options: ["ყ", "ქ"], kaOptions: true)
    check("auto: wrong, the word with its missing letter", AutoSpeech.onCheck(missing, given: .choice(1), correct: false), "წყალი")
    let listen = choice(.listening, prompt: "წყალი", ka: true, options: ["water", "bread"], kaOptions: false, audio: "წყალი")
    check("auto: listening plays itself, not twice", AutoSpeech.onShow(listen), nil)
    check("auto: listening right, nothing after Check", AutoSpeech.onCheck(listen, given: .choice(0), correct: true), nil)
    check("auto: listening wrong, heard again", AutoSpeech.onCheck(listen, given: .choice(1), correct: false), "წყალი")
    let sentence = Exercise(id: "s", kind: .sentenceBuilder, instruction: "", itemID: nil, content: .tiles(Tiles(
        prompt: "I want water", promptDetail: nil, answer: ["წყალი", "მინდა"], bank: ["მინდა", "წყალი", "პური"], joiner: " ", isSpelling: false)))
    check("auto: a word tile added is said", AutoSpeech.onPick(sentence, from: .tiles(["წყალი"]), to: .tiles(["წყალი", "მინდა"])), "მინდა")
    check("auto: a tile taken away isn't", AutoSpeech.onPick(sentence, from: .tiles(["წყალი", "მინდა"]), to: .tiles(["წყალი"])), nil)
    check("auto: wrong sentence, the right one after Check", AutoSpeech.onCheck(sentence, given: .tiles(["მინდა", "წყალი"]), correct: false), "წყალი მინდა")
    let spell = Exercise(id: "p", kind: .spelling, instruction: "", itemID: nil, content: .tiles(Tiles(
        prompt: "water", promptDetail: nil, answer: ["წ", "ყ", "ა", "ლ", "ი"], bank: ["ა", "ი", "ლ", "წ", "ყ"], joiner: "", isSpelling: true)))
    check("auto: a spelling letter tapped is said", AutoSpeech.onPick(spell, from: nil, to: .tiles(["წ"])), "წ")
    let partner = DialogueLine(speaker: "Nana", ka: "როგორ ხარ?", lat: "rogor khar?", en: "How are you?", isLearner: false, wrong: nil)
    let mine = DialogueLine(speaker: "me", ka: "კარგად.", lat: "k'argad.", en: "Fine.", isLearner: true, wrong: ["ცუდად."])
    let turn = Exercise(id: "d", kind: .dialogue, instruction: "", itemID: nil, content: .dialogue(DialogueTurn(
        partner: "Nana", history: [partner], line: mine, options: ["ცუდად.", "კარგად."], answer: 1)))
    check("auto: what the partner just said", AutoSpeech.onShow(turn), "როგორ ხარ?")
    check("auto: the reply picked", AutoSpeech.onPick(turn, from: nil, to: .choice(0)), "ცუდად.")
    check("auto: the right reply after a wrong one", AutoSpeech.onCheck(turn, given: .choice(0), correct: false), "კარგად.")
    check("auto: a matching letter is said", AutoSpeech.onMatchTap("ბ"), "ბ")
    check("auto: a matching word is", AutoSpeech.onMatchTap("წყალი"), "წყალი")
}

print("\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
