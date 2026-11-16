import SwiftUI

/// Draws any exercise: the instruction, then the view for its content shape.
struct ExerciseView: View {
    let exercise: Exercise
    @Bindable var model: LessonPlayerModel

    private var revealed: Evaluation? {
        if case .feedback(let e) = model.phase { return e }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(exercise.instruction)
                .font(.title2Bold)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("instruction")
            switch exercise.content {
            case .teachLetter(let l):
                TeachLetterView(letter: l)
            case .teachWord(let w):
                TeachWordView(word: w)
            case .note(let n):
                NoteView(note: n)
            case .choice(let c):
                ChoiceExerciseView(choice: c, kind: exercise.kind, selection: choiceBinding, revealed: revealed)
            case .typing(let t):
                TypingExerciseView(typing: t, text: textBinding, revealed: revealed) { model.check() }
            case .matching(let pairs):
                MatchingExerciseView(pairs: pairs, exerciseID: exercise.id) { mistakes in
                    model.check(.matched(mistakes: mistakes))
                }
            case .tiles(let t):
                TilesExerciseView(tiles: t, chosen: tilesBinding, revealed: revealed)
            case .flashcard(let f):
                FlashcardExerciseView(card: f, revealed: revealed) { knew in model.check(.recalled(knew)) }
            case .dialogue(let d):
                DialogueExerciseView(turn: d, selection: choiceBinding, revealed: revealed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var choiceBinding: Binding<Int?> {
        Binding(get: {
            if case .choice(let i) = model.pending { return i }
            return nil
        }, set: { model.pending = $0.map(Answer.choice) })
    }

    private var textBinding: Binding<String> {
        Binding(get: {
            if case .text(let s) = model.pending { return s }
            return ""
        }, set: { model.pending = .text($0) })
    }

    private var tilesBinding: Binding<[Int]> {
        Binding(get: { tileIndices }, set: { indices in
            tileIndices = indices
            if case .tiles(let t) = exercise.content {
                model.pending = indices.isEmpty ? nil : .tiles(indices.map { t.bank[$0] })
            }
        })
    }

    @State private var tileIndices: [Int] = []
}

// MARK: Teaching cards

struct TeachLetterView: View {
    let letter: LetterInfo
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(Gradients.hero)
                    .shadow(color: Palette.pomegranate.opacity(0.35), radius: 20, y: 10)
                Borjgali(size: 220, colors: [.white.opacity(0.10), .white.opacity(0.02), .white.opacity(0.10)])
                GeorgianText(letter.char, size: 120, weight: .bold, color: .white)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
            }
            .frame(width: 210, height: 210)
            .frame(maxWidth: .infinity)
            .accessibilityElement()
            .accessibilityLabel("The letter \(letter.name), written \(letter.latin)")

            HStack(spacing: 10) {
                Pill(text: "Name: \(letter.name)", color: Palette.saperavi)
                Pill(text: "Written \(letter.latin)", color: Palette.blacksea)
                SpeakerButton(text: letter.char, size: 36)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Label("Sounds like \(letter.sound)", systemImage: "mouth.fill")
                    .font(.headlineRounded)
                    .foregroundStyle(Palette.ink)
                if !letter.tip.isEmpty {
                    Text(letter.tip)
                        .font(.calloutRounded)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card()

            HStack(spacing: 14) {
                GeorgianText(letter.word, size: 30, weight: .bold, color: Palette.pomegranate)
                VStack(alignment: .leading, spacing: 2) {
                    Text(letter.wordLatin).font(.headlineRounded).foregroundStyle(Palette.ink)
                    Text(letter.meaning).font(.calloutRounded).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                SpeakerButton(text: letter.word, size: 36)
            }
            .card()
            .accessibilityElement(children: .combine)
        }
        .onAppear { withMotion(Motion.bouncy) { appeared = true } }
    }
}

struct TeachWordView: View {
    let word: Word
    @Environment(LearningStore.self) private var store

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                GeorgianText(word.ka, size: 44, weight: .bold, color: .white)
                Text(word.lat).font(.headlineRounded).foregroundStyle(.white.opacity(0.85))
                Text(word.en).font(.title2Bold).foregroundStyle(.white)
                SpeakerButton(text: word.ka, size: 40, showsSource: true)
            }
            .frame(maxWidth: .infinity)
            .gradientCard(BrandColor(named: store.curriculum.category(word.category)?.color ?? "saperavi"))
            .accessibilityElement(children: .combine)

            let hints = Pronunciation.hints(for: word.ka, in: store.curriculum)
            if !hints.isEmpty || word.pron != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Say it", systemImage: "waveform").font(.headlineRounded).foregroundStyle(Palette.blacksea)
                    if let p = word.pron { Text(p).font(.calloutRounded).foregroundStyle(Palette.ink) }
                    ForEach(hints, id: \.self) { Text($0).font(.calloutRounded).foregroundStyle(Palette.inkSoft) }
                }
                .card()
            }

            ExampleCard(example: word.example)

            if let note = word.note {
                Label(note, systemImage: "lightbulb.fill")
                    .font(.calloutRounded)
                    .foregroundStyle(Palette.ink)
                    .card()
            }
        }
    }
}

struct ExampleCard: View {
    let example: Gloss

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Example").font(.captionBold).foregroundStyle(Palette.gold).textCase(.uppercase)
                Spacer()
                SpeakerButton(text: example.ka, size: 32)
            }
            Text(example.ka).font(.system(.title3, weight: .semibold)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            Text(example.lat).font(.calloutRounded.italic()).foregroundStyle(Palette.inkSoft)
            Text(example.en).font(.bodyRounded).foregroundStyle(Palette.ink)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct NoteView: View {
    let note: GrammarNote

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(note.title)
                .font(.titleBold)
                .foregroundStyle(Palette.saperavi)
            Text(note.text)
                .font(.bodyRounded)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !note.table.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(note.table.enumerated()), id: \.offset) { i, row in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.ka).font(.system(.title3, weight: .bold)).foregroundStyle(Palette.ink)
                                Text(row.lat).font(.caption.italic()).foregroundStyle(Palette.inkSoft)
                            }
                            Spacer(minLength: 8)
                            Text(row.en)
                                .font(.calloutRounded)
                                .foregroundStyle(Palette.inkSoft)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(i % 2 == 0 ? Palette.surfaceRaised.opacity(0.7) : Color.clear)
                        .accessibilityElement(children: .combine)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
            }
        }
        .card()
    }
}
