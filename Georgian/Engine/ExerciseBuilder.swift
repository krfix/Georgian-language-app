import Foundation

/// Turns a lesson into its exercises. Letter and word lessons are made entirely from their
/// content; grammar and conversation lessons add the exercises written in the course.
/// The same seed always gives the same lesson (the tests rely on it).
struct ExerciseBuilder {
    let curriculum: Curriculum
    /// Whether a Georgian voice or recording exists for this text: listening exercises are
    /// only made when one does.
    var hasAudio: (String) -> Bool = { _ in false }

    // MARK: Lessons

    func exercises<G: RandomNumberGenerator>(for lesson: Lesson, using rng: inout G) -> [Exercise] {
        switch lesson.kind {
        case .letters: return letterLesson(lesson, using: &rng)
        case .contrast: return contrastLesson(lesson, using: &rng)
        case .vocabulary, .phrases: return wordLesson(lesson, using: &rng)
        case .grammar: return grammarLesson(lesson, using: &rng)
        case .conversation: return conversationLesson(lesson, using: &rng)
        }
    }

    private func letterLesson<G: RandomNumberGenerator>(_ lesson: Lesson, using rng: inout G) -> [Exercise] {
        let new = (lesson.letters ?? []).compactMap(curriculum.letter)
        let known = curriculum.lettersTaught(through: lesson.id)
        var out: [Exercise] = []
        // Meet each letter, then recognise it straight away.
        for (i, l) in new.enumerated() {
            out.append(Exercise(id: "\(lesson.id).teach.\(l.char)", kind: .teachLetter,
                                instruction: "New letter", itemID: l.itemID, content: .teachLetter(l)))
            out.append(letterToLatin(l, among: known, id: "\(lesson.id).rec.\(l.char)", using: &rng))
            if i > 0 { out.append(latinToLetter(new[i - 1], among: known, id: "\(lesson.id).back.\(new[i - 1].char)", using: &rng)) }
        }
        if let last = new.last { out.append(latinToLetter(last, among: known, id: "\(lesson.id).back.\(last.char)", using: &rng)) }
        if new.count >= 3 {
            out.append(matching(lettersPairs(new), id: "\(lesson.id).match", instruction: "Match each letter to its sound"))
        }
        let read = lesson.read ?? []
        let newChars = Set(new.map(\.char))
        // Missing letter: a reading word with one of today's letters taken out.
        for (i, g) in read.enumerated() where i < 3 {
            if let ex = missingLetter(in: g, preferring: newChars.isEmpty ? Set(known.map(\.char)) : newChars,
                                      among: known, id: "\(lesson.id).missing.\(i)", using: &rng) {
                out.append(ex)
            }
        }
        // Read the words aloud (choose the Latin), then say what they mean.
        for (i, g) in read.enumerated() {
            out.append(reading(g, id: "\(lesson.id).read.\(i)", using: &rng))
        }
        for (i, g) in read.enumerated() where i % 2 == 0 || new.isEmpty {
            out.append(meaning(g, others: read, id: "\(lesson.id).mean.\(i)", using: &rng))
        }
        if new.isEmpty {
            // The review lesson: match the whole alphabet in groups, and spell two words.
            for (n, chunk) in known.chunked(into: 6).enumerated() where n < 3 {
                out.append(matching(lettersPairs(chunk.shuffled(using: &rng)), id: "\(lesson.id).match.\(n)",
                                    instruction: "Match each letter to its sound"))
            }
            for (i, g) in read.prefix(2).enumerated() {
                out.append(spelling(g, itemID: nil, letters: known, id: "\(lesson.id).spell.\(i)", using: &rng))
            }
        }
        if let g = read.first(where: { hasAudio($0.ka) }) {
            out.append(listening(prompt: g.ka, right: g.en, others: read.map(\.en), itemID: nil,
                                 id: "\(lesson.id).listen", using: &rng))
        }
        return out
    }

    private func contrastLesson<G: RandomNumberGenerator>(_ lesson: Lesson, using rng: inout G) -> [Exercise] {
        var out: [Exercise] = []
        let pairs = (lesson.pairs ?? []).map { $0.compactMap(curriculum.letter) }.filter { $0.count == 2 }
        let table = pairs.flatMap { $0 }.map { Gloss(ka: $0.char, lat: $0.latin, en: $0.sound) }
        out.append(Exercise(id: "\(lesson.id).note", kind: .note, instruction: "Listen with your eyes",
                            itemID: nil, content: .note(GrammarNote(title: lesson.title, text: lesson.note ?? "", table: table))))
        for (i, p) in pairs.enumerated() {
            let target = p[i % 2]
            let options = p.shuffled(using: &rng)
            let choice = Choice(prompt: "Which letter is \(target.latin)?", promptIsGeorgian: false,
                                promptDetail: target.sound,
                                options: options.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element.char, detail: nil) },
                                optionsAreGeorgian: true,
                                answer: options.firstIndex(of: target) ?? 0,
                                explanation: "\(p[0].char) is \(p[0].latin): \(p[0].sound). \(p[1].char) is \(p[1].latin): \(p[1].sound).",
                                audioText: nil)
            out.append(Exercise(id: "\(lesson.id).pair.\(i)", kind: .letterRecognition, instruction: "Tight or with air?",
                                itemID: target.itemID, content: .choice(choice)))
        }
        out.append(matching(lettersPairs(Array(pairs.flatMap { $0 }.prefix(6))), id: "\(lesson.id).match",
                            instruction: "Match each letter to its sound"))
        let read = lesson.read ?? []
        for (i, g) in read.enumerated() {
            out.append(i % 2 == 0 ? reading(g, id: "\(lesson.id).read.\(i)", using: &rng)
                                  : meaning(g, others: read, id: "\(lesson.id).mean.\(i)", using: &rng))
        }
        return out
    }

    private func wordLesson<G: RandomNumberGenerator>(_ lesson: Lesson, using rng: inout G) -> [Exercise] {
        let words = curriculum.words(in: lesson)
        var pool = curriculum.words.filter { $0.category == (words.first?.category ?? "") }
        if pool.count < 6 { pool = curriculum.words }
        var out: [Exercise] = []
        // Teach two words, then test the one before: each word is seen, then asked.
        for (i, w) in words.enumerated() {
            out.append(Exercise(id: "\(lesson.id).teach.\(w.id)", kind: .teachWord, instruction: "New word",
                                itemID: w.id, content: .teachWord(w)))
            if i >= 1 {
                let prev = words[i - 1]
                out.append(i % 2 == 1 ? georgianToEnglish(prev, pool: words + pool, id: "\(lesson.id).ke.\(prev.id)", using: &rng)
                                      : englishToGeorgian(prev, pool: words + pool, id: "\(lesson.id).ek.\(prev.id)", using: &rng))
            }
        }
        if let last = words.last { out.append(englishToGeorgian(last, pool: words + pool, id: "\(lesson.id).ek.\(last.id)", using: &rng)) }
        out.append(matching(wordPairs(Array(words.shuffled(using: &rng).prefix(5))), id: "\(lesson.id).match",
                            instruction: "Tap the pairs"))
        let shuffled = words.shuffled(using: &rng)
        // Fill the gap in an example sentence.
        var fills = 0
        for w in shuffled where fills < 2 {
            if let ex = fillBlank(w, pool: words + pool, id: "\(lesson.id).fill.\(w.id)", using: &rng) {
                out.append(ex); fills += 1
            }
        }
        // Spell a short word with letter tiles.
        if let w = shuffled.first(where: { $0.isSingleWord && $0.bare.count >= 2 && $0.bare.count <= 7 }) {
            out.append(spelling(Gloss(ka: w.bare, lat: w.lat, en: w.en), itemID: w.id, letters: curriculum.letters,
                                id: "\(lesson.id).spell", using: &rng))
        }
        // Type the meaning.
        for w in shuffled.suffix(2) {
            out.append(translation(w, id: "\(lesson.id).type.\(w.id)"))
        }
        // Build a sentence: the example (words) or the phrase itself.
        var builds = 0
        for w in shuffled.reversed() where builds < (lesson.kind == .phrases ? 2 : 1) {
            let sentence = lesson.kind == .phrases ? Gloss(ka: w.ka, lat: w.lat, en: w.en) : w.example
            if let ex = sentenceBuilder(sentence, distractorsFrom: words.map { lesson.kind == .phrases ? $0.ka : $0.example.ka },
                                        itemID: w.id, id: "\(lesson.id).build.\(w.id)", using: &rng) {
                out.append(ex); builds += 1
            }
        }
        if let w = shuffled.first(where: { hasAudio($0.ka) }) {
            out.append(listening(prompt: w.ka, right: w.en, others: (words + pool).map(\.en), itemID: w.id,
                                 id: "\(lesson.id).listen", using: &rng))
        }
        return out
    }

    private func grammarLesson<G: RandomNumberGenerator>(_ lesson: Lesson, using rng: inout G) -> [Exercise] {
        var out: [Exercise] = []
        for (i, n) in (lesson.notes ?? []).enumerated() {
            out.append(Exercise(id: "\(lesson.id).note.\(i)", kind: .note, instruction: "Grammar", itemID: nil, content: .note(n)))
        }
        let words = curriculum.words(in: lesson)
        for w in words.prefix(4) {
            out.append(flashcard(w, id: "\(lesson.id).card.\(w.id)"))
        }
        out.append(contentsOf: authored(lesson, using: &rng))
        if words.count >= 3 {
            out.append(matching(wordPairs(Array(words.prefix(5))), id: "\(lesson.id).match", instruction: "Tap the pairs"))
        }
        return out
    }

    private func conversationLesson<G: RandomNumberGenerator>(_ lesson: Lesson, using rng: inout G) -> [Exercise] {
        guard let d = lesson.dialogue else { return authored(lesson, using: &rng) }
        var out: [Exercise] = []
        var history: [DialogueLine] = []
        for (i, line) in d.lines.enumerated() {
            if line.isLearner, let wrong = line.wrong {
                let options = ([line.ka] + wrong).shuffled(using: &rng)
                out.append(Exercise(id: "\(lesson.id).turn.\(i)", kind: .dialogue, instruction: "Choose your reply",
                                    itemID: nil,
                                    content: .dialogue(DialogueTurn(partner: d.partner, history: history, line: line,
                                                                    options: options, answer: options.firstIndex(of: line.ka) ?? 0))))
            }
            history.append(line)
        }
        // What did they say? Two of the partner's lines.
        let partnerLines = d.lines.filter { !$0.isLearner }
        for (i, line) in partnerLines.enumerated() where i == 0 || i == partnerLines.count / 2 {
            let g = Gloss(ka: line.ka, lat: line.lat, en: line.en)
            let others = d.lines.map { Gloss(ka: $0.ka, lat: $0.lat, en: $0.en) }
            if hasAudio(line.ka) {
                out.append(listening(prompt: line.ka, right: line.en, others: others.map(\.en), itemID: nil,
                                     id: "\(lesson.id).listen.\(i)", using: &rng))
            } else {
                out.append(meaning(g, others: others, id: "\(lesson.id).mean.\(i)", using: &rng))
            }
        }
        out.append(contentsOf: authored(lesson, using: &rng))
        return out
    }

    /// The exercises written in the course for this lesson.
    private func authored<G: RandomNumberGenerator>(_ lesson: Lesson, using rng: inout G) -> [Exercise] {
        (lesson.exercises ?? []).enumerated().compactMap { pair -> Exercise? in
            let (i, spec) = (pair.offset, pair.element)
            let id = "\(lesson.id).x.\(i)"
            switch spec.type {
            case "choice":
                guard let options = spec.options, let answer = spec.answer else { return nil }
                let georgian = options.allSatisfy { Self.isGeorgian($0) }
                return choiceExercise(prompt: spec.prompt ?? "", promptIsGeorgian: false, detail: nil, options: options,
                                      answer: answer, optionsAreGeorgian: georgian, explanation: spec.explanation,
                                      kind: .multipleChoice, instruction: "Choose the right answer", itemID: nil, id: id, using: &rng)
            case "fill":
                guard let options = spec.options, let answer = spec.answer, let sentence = spec.sentence else { return nil }
                return choiceExercise(prompt: sentence, promptIsGeorgian: true, detail: spec.translation, options: options,
                                      answer: answer, optionsAreGeorgian: true, explanation: spec.explanation,
                                      kind: .fillBlank, instruction: "Fill in the gap", itemID: nil, id: id, using: &rng)
            case "build":
                guard let tiles = spec.tiles else { return nil }
                let bank = (tiles + (spec.extra ?? [])).shuffled(using: &rng)
                return Exercise(id: id, kind: .sentenceBuilder, instruction: "Build the sentence", itemID: nil,
                                content: .tiles(Tiles(prompt: spec.english ?? "", promptDetail: nil, answer: tiles, bank: bank,
                                                      joiner: " ", isSpelling: false)))
            default:
                return nil
            }
        }
    }

    // MARK: Review

    /// A review session over letters and words that are due, mixing the exercise kinds.
    func review<G: RandomNumberGenerator>(_ items: [StudyItem], using rng: inout G) -> [Exercise] {
        var out: [Exercise] = []
        let pool = curriculum.words
        for (i, item) in items.enumerated() {
            let id = "review.\(i).\(item.id)"
            switch item {
            case .letter(let l):
                let known = curriculum.letters
                out.append(i % 2 == 0 ? letterToLatin(l, among: known, id: id, using: &rng)
                                      : latinToLetter(l, among: known, id: id, using: &rng))
            case .word(let w):
                switch i % 4 {
                case 0: out.append(georgianToEnglish(w, pool: pool.filter { $0.category == w.category } + pool, id: id, using: &rng))
                case 1: out.append(englishToGeorgian(w, pool: pool.filter { $0.category == w.category } + pool, id: id, using: &rng))
                case 2: out.append(translation(w, id: id))
                default: out.append(flashcard(w, id: id))
                }
            }
        }
        return out
    }

    // MARK: Pieces

    private func letterToLatin<G: RandomNumberGenerator>(_ l: LetterInfo, among known: [LetterInfo], id: String, using rng: inout G) -> Exercise {
        let others = distractorLetters(for: l, among: known, using: &rng)
        let options = ([l] + others).shuffled(using: &rng)
        let choice = Choice(prompt: l.char, promptIsGeorgian: true, promptDetail: nil,
                            options: options.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element.latin, detail: nil) },
                            optionsAreGeorgian: false, answer: options.firstIndex(of: l) ?? 0,
                            explanation: "\(l.char) sounds like \(l.sound).", audioText: nil)
        return Exercise(id: id, kind: .letterRecognition, instruction: "What sound does this letter make?",
                        itemID: l.itemID, content: .choice(choice))
    }

    private func latinToLetter<G: RandomNumberGenerator>(_ l: LetterInfo, among known: [LetterInfo], id: String, using rng: inout G) -> Exercise {
        let others = distractorLetters(for: l, among: known, using: &rng)
        let options = ([l] + others).shuffled(using: &rng)
        let choice = Choice(prompt: l.latin, promptIsGeorgian: false, promptDetail: l.sound,
                            options: options.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element.char, detail: nil) },
                            optionsAreGeorgian: true, answer: options.firstIndex(of: l) ?? 0,
                            explanation: "\(l.latin) is written \(l.char).", audioText: nil)
        return Exercise(id: id, kind: .letterRecognition, instruction: "Which letter makes this sound?",
                        itemID: l.itemID, content: .choice(choice))
    }

    /// Three wrong letters: look-alikes first, then letters already taught, then any.
    func distractorLetters<G: RandomNumberGenerator>(for l: LetterInfo, among known: [LetterInfo], count: Int = 3, using rng: inout G) -> [LetterInfo] {
        var out: [LetterInfo] = []
        func add(_ list: [LetterInfo]) {
            for c in list.shuffled(using: &rng) where out.count < count && c != l && !out.contains(c) { out.append(c) }
        }
        add(curriculum.lookalikes(of: l.char).compactMap(curriculum.letter).filter { known.contains($0) })
        add(known)
        add(curriculum.letters)
        return out
    }

    private func lettersPairs(_ letters: [LetterInfo]) -> [MatchPair] {
        letters.map { MatchPair(id: $0.itemID, georgian: $0.char, other: $0.latin) }
    }

    private func wordPairs(_ words: [Word]) -> [MatchPair] {
        var seen = Set<String>()
        return words.filter { seen.insert($0.en).inserted }.map { MatchPair(id: $0.id, georgian: $0.ka, other: $0.en) }
    }

    private func matching(_ pairs: [MatchPair], id: String, instruction: String) -> Exercise {
        Exercise(id: id, kind: .matching, instruction: instruction, itemID: nil, content: .matching(pairs))
    }

    private func missingLetter<G: RandomNumberGenerator>(in g: Gloss, preferring: Set<String>, among known: [LetterInfo], id: String, using rng: inout G) -> Exercise? {
        let chars = g.ka.map(String.init)
        let positions = chars.indices.filter { preferring.contains(chars[$0]) }
        guard let pos = positions.randomElement(using: &rng), let target = curriculum.letter(chars[pos]) else { return nil }
        var shown = chars
        shown[pos] = "_"
        let options = ([target] + distractorLetters(for: target, among: known, using: &rng)).shuffled(using: &rng)
        let choice = Choice(prompt: shown.joined(), promptIsGeorgian: true, promptDetail: "\(g.lat) · \(g.en)",
                            options: options.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element.char, detail: nil) },
                            optionsAreGeorgian: true, answer: options.firstIndex(of: target) ?? 0,
                            explanation: "\(g.ka) is \(g.lat).", audioText: nil)
        return Exercise(id: id, kind: .missingLetter, instruction: "Which letter is missing?", itemID: target.itemID, content: .choice(choice))
    }

    /// Read a word: choose its Latin spelling among near misses (one letter swapped for a look-alike).
    private func reading<G: RandomNumberGenerator>(_ g: Gloss, id: String, using rng: inout G) -> Exercise {
        var options = [g.lat]
        let chars = g.ka.map(String.init)
        var attempts = 0
        while options.count < 4 && attempts < 30 {
            attempts += 1
            var changed = chars
            guard let pos = chars.indices.randomElement(using: &rng), let l = curriculum.letter(chars[pos]) else { continue }
            let swaps = curriculum.lookalikes(of: l.char)
            let pick = swaps.randomElement(using: &rng) ?? curriculum.letters.randomElement(using: &rng)?.char ?? l.char
            changed[pos] = pick
            let lat = curriculum.latin(changed.joined())
            if !options.contains(lat) { options.append(lat) }
        }
        let shuffled = options.shuffled(using: &rng)
        let choice = Choice(prompt: g.ka, promptIsGeorgian: true, promptDetail: nil,
                            options: shuffled.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element, detail: nil) },
                            optionsAreGeorgian: false, answer: shuffled.firstIndex(of: g.lat) ?? 0,
                            explanation: "\(g.ka) reads \(g.lat): \(g.en).", audioText: nil)
        return Exercise(id: id, kind: .reading, instruction: "Read this word", itemID: nil, content: .choice(choice))
    }

    private func meaning<G: RandomNumberGenerator>(_ g: Gloss, others: [Gloss], id: String, using rng: inout G) -> Exercise {
        var options = [g.en]
        for o in others.shuffled(using: &rng) where options.count < 4 && !options.contains(o.en) { options.append(o.en) }
        for w in curriculum.words.shuffled(using: &rng) where options.count < 4 && !options.contains(w.en) { options.append(w.en) }
        let shuffled = options.shuffled(using: &rng)
        let choice = Choice(prompt: g.ka, promptIsGeorgian: true, promptDetail: g.lat,
                            options: shuffled.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element, detail: nil) },
                            optionsAreGeorgian: false, answer: shuffled.firstIndex(of: g.en) ?? 0, explanation: nil, audioText: nil)
        return Exercise(id: id, kind: .multipleChoice, instruction: "What does it mean?", itemID: nil, content: .choice(choice))
    }

    private func georgianToEnglish<G: RandomNumberGenerator>(_ w: Word, pool: [Word], id: String, using rng: inout G) -> Exercise {
        let others = distractorWords(for: w, pool: pool, using: &rng)
        let options = ([w] + others).shuffled(using: &rng)
        let choice = Choice(prompt: w.ka, promptIsGeorgian: true, promptDetail: w.lat,
                            options: options.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element.en, detail: nil) },
                            optionsAreGeorgian: false, answer: options.firstIndex(of: w) ?? 0, explanation: w.note, audioText: nil)
        return Exercise(id: id, kind: .multipleChoice, instruction: "What does it mean?", itemID: w.id, content: .choice(choice))
    }

    private func englishToGeorgian<G: RandomNumberGenerator>(_ w: Word, pool: [Word], id: String, using rng: inout G) -> Exercise {
        let others = distractorWords(for: w, pool: pool, using: &rng)
        let options = ([w] + others).shuffled(using: &rng)
        let choice = Choice(prompt: w.en, promptIsGeorgian: false, promptDetail: nil,
                            options: options.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element.ka, detail: $0.element.lat) },
                            optionsAreGeorgian: true, answer: options.firstIndex(of: w) ?? 0, explanation: w.note, audioText: nil)
        return Exercise(id: id, kind: .multipleChoice, instruction: "How do you say it in Georgian?", itemID: w.id, content: .choice(choice))
    }

    /// Three other words with different meanings and spellings.
    private func distractorWords<G: RandomNumberGenerator>(for w: Word, pool: [Word], using rng: inout G) -> [Word] {
        var out: [Word] = []
        for c in (pool.shuffled(using: &rng) + curriculum.words.shuffled(using: &rng)) where out.count < 3 {
            if c.id != w.id && c.en != w.en && c.ka != w.ka && !out.contains(where: { $0.en == c.en || $0.ka == c.ka }) {
                out.append(c)
            }
        }
        return out
    }

    private func translation(_ w: Word, id: String) -> Exercise {
        Exercise(id: id, kind: .translation, instruction: "Type it in English", itemID: w.id,
                 content: .typing(Typing(prompt: w.ka, promptLatin: w.lat, accepted: AnswerEvaluator.acceptedEnglish(for: w), display: w.en)))
    }

    private func flashcard(_ w: Word, id: String) -> Exercise {
        Exercise(id: id, kind: .flashcard, instruction: "Do you remember it?", itemID: w.id,
                 content: .flashcard(Flashcard(front: w.ka, frontLatin: w.lat, back: w.en, note: w.note)))
    }

    /// The example sentence with the word taken out, when the word appears in it as it is.
    private func fillBlank<G: RandomNumberGenerator>(_ w: Word, pool: [Word], id: String, using rng: inout G) -> Exercise? {
        let target = w.bare
        let tokens = w.example.ka.split(separator: " ").map(String.init)
        guard w.isSingleWord, let pos = tokens.firstIndex(where: { Self.stripPunctuation($0) == target }) else { return nil }
        var shown = tokens
        let token = tokens[pos]
        shown[pos] = token.replacingOccurrences(of: target, with: "___")
        var options = [target]
        for c in pool.shuffled(using: &rng) where options.count < 4 && c.isSingleWord && !options.contains(c.bare) {
            options.append(c.bare)
        }
        let shuffled = options.shuffled(using: &rng)
        let choice = Choice(prompt: shown.joined(separator: " "), promptIsGeorgian: true, promptDetail: w.example.en,
                            options: shuffled.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element, detail: curriculum.latin($0.element)) },
                            optionsAreGeorgian: true, answer: shuffled.firstIndex(of: target) ?? 0,
                            explanation: "\(w.example.ka) — \(w.example.lat)", audioText: nil)
        return Exercise(id: id, kind: .fillBlank, instruction: "Fill in the gap", itemID: w.id, content: .choice(choice))
    }

    private func spelling<G: RandomNumberGenerator>(_ g: Gloss, itemID: String?, letters: [LetterInfo], id: String, using rng: inout G) -> Exercise {
        let answer = g.ka.map(String.init)
        var bank = answer
        var extra: [String] = []
        for ch in Set(answer) {
            guard let l = curriculum.letter(ch) else { continue }
            if let alike = curriculum.lookalikes(of: l.char).first(where: { !answer.contains($0) && !extra.contains($0) }) {
                extra.append(alike)
            }
            if extra.count >= 3 { break }
        }
        bank += extra
        return Exercise(id: id, kind: .spelling, instruction: "Spell it in Georgian", itemID: itemID,
                        content: .tiles(Tiles(prompt: g.en, promptDetail: g.lat, answer: answer, bank: bank.shuffled(using: &rng),
                                              joiner: "", isSpelling: true)))
    }

    private func sentenceBuilder<G: RandomNumberGenerator>(_ g: Gloss, distractorsFrom sentences: [String], itemID: String?, id: String, using rng: inout G) -> Exercise? {
        let tiles = g.ka.split(separator: " ").map(String.init).filter { $0 != "—" }
        guard tiles.count >= 2 && tiles.count <= 7 else { return nil }
        var extra: [String] = []
        for s in sentences.shuffled(using: &rng) {
            for t in s.split(separator: " ").map(String.init) where t != "—" && !tiles.contains(t) && !extra.contains(t) && extra.count < 2 {
                extra.append(t)
            }
        }
        return Exercise(id: id, kind: .sentenceBuilder, instruction: "Build the sentence", itemID: itemID,
                        content: .tiles(Tiles(prompt: g.en, promptDetail: nil, answer: tiles,
                                              bank: (tiles + extra).shuffled(using: &rng), joiner: " ", isSpelling: false)))
    }

    private func listening<G: RandomNumberGenerator>(prompt: String, right: String, others: [String], itemID: String?, id: String, using rng: inout G) -> Exercise {
        var options = [right]
        for o in others.shuffled(using: &rng) where options.count < 4 && !options.contains(o) { options.append(o) }
        let shuffled = options.shuffled(using: &rng)
        let choice = Choice(prompt: prompt, promptIsGeorgian: true, promptDetail: nil,
                            options: shuffled.enumerated().map { ChoiceOption(id: $0.offset, text: $0.element, detail: nil) },
                            optionsAreGeorgian: false, answer: shuffled.firstIndex(of: right) ?? 0,
                            explanation: prompt, audioText: prompt)
        return Exercise(id: id, kind: .listening, instruction: "What did you hear?", itemID: itemID, content: .choice(choice))
    }

    private func choiceExercise<G: RandomNumberGenerator>(prompt: String, promptIsGeorgian: Bool, detail: String?, options: [String],
                                                          answer: Int, optionsAreGeorgian: Bool, explanation: String?,
                                                          kind: ExerciseKind, instruction: String, itemID: String?, id: String,
                                                          using rng: inout G) -> Exercise {
        let right = options[min(max(answer, 0), options.count - 1)]
        let shuffled = options.shuffled(using: &rng)
        let choice = Choice(prompt: prompt, promptIsGeorgian: promptIsGeorgian, promptDetail: detail,
                            options: shuffled.enumerated().map {
                                ChoiceOption(id: $0.offset, text: $0.element, detail: optionsAreGeorgian ? curriculum.latin($0.element) : nil)
                            },
                            optionsAreGeorgian: optionsAreGeorgian, answer: shuffled.firstIndex(of: right) ?? 0,
                            explanation: (explanation?.isEmpty ?? true) ? nil : explanation, audioText: nil)
        return Exercise(id: id, kind: kind, instruction: instruction, itemID: itemID, content: .choice(choice))
    }

    static func isGeorgian(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x10D0...0x10FF).contains($0.value) } && !s.unicodeScalars.contains { CharacterSet.letters.contains($0) && $0.value < 0x250 }
    }

    static func stripPunctuation(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: ".,?!—:;\""))
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
