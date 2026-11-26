import SwiftUI

/// Tap a Georgian tile, then its partner. Matched pairs turn green; a wrong pair shakes.
/// Calls `onComplete` with the number of wrong pairs once all are matched.
struct MatchingExerciseView: View {
    let pairs: [MatchPair]
    let exerciseID: String
    let onComplete: (Int) -> Void

    @State private var left: [MatchPair] = []
    @State private var right: [MatchPair] = []
    @State private var pickedLeft: String?
    @State private var pickedRight: String?
    @State private var matched: Set<String> = []
    @State private var wrongFlash: Set<String> = []
    @State private var mistakes = 0
    @Environment(AudioService.self) private var audio

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 12) {
                ForEach(left) { p in
                    tile(p.georgian, id: p.id, side: .georgian)
                        .accessibilityIdentifier("match-ka-\(p.id)")
                }
            }
            VStack(spacing: 12) {
                ForEach(right) { p in
                    tile(p.other, id: p.id, side: .other)
                        .accessibilityIdentifier("match-other-\(p.id)")
                }
            }
        }
        .onAppear {
            guard left.isEmpty else { return }
            var rng = SeededGenerator(seed: UInt64(abs(exerciseID.hashValue % 10_000)))
            left = pairs.shuffled(using: &rng)
            right = pairs.shuffled(using: &rng)
        }
    }

    private enum Side { case georgian, other }

    private func tile(_ text: String, id: String, side: Side) -> some View {
        let isMatched = matched.contains(id)
        let isPicked = side == .georgian ? pickedLeft == id : pickedRight == id
        let isWrong = wrongFlash.contains("\(side)-\(id)")
        let color: Color = isMatched ? Palette.success : isWrong ? Palette.error : isPicked ? Palette.blacksea : Palette.line
        return Button {
            tap(id, side: side)
        } label: {
            Group {
                if side == .georgian {
                    GeorgianText(text, size: text.count <= 2 ? 32 : 22)
                } else {
                    Text(text)
                        .font(.headlineRounded)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isMatched ? Palette.success.opacity(0.14) : Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(color, lineWidth: isPicked || isWrong ? 3 : 2))
            .opacity(isMatched ? 0.55 : 1)
            .scaleEffect(isPicked ? 1.04 : 1)
            .modifier(Shake(amount: isWrong ? 1 : 0))
        }
        .buttonStyle(.pressable)
        .disabled(isMatched)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
        .accessibilityValue(isMatched ? "matched" : "")
    }

    private func tap(_ id: String, side: Side) {
        Haptics.select()
        if side == .georgian, let pair = pairs.first(where: { $0.id == id }) {
            audio.autoSay(AutoSpeech.onMatchTap(pair.georgian))
        }
        withMotion(Motion.spring) {
            if side == .georgian { pickedLeft = pickedLeft == id ? nil : id } else { pickedRight = pickedRight == id ? nil : id }
        }
        guard let l = pickedLeft, let r = pickedRight else { return }
        if l == r {
            Haptics.success()
            withMotion(Motion.bouncy) {
                matched.insert(l)
                pickedLeft = nil
                pickedRight = nil
            }
            if matched.count == pairs.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onComplete(mistakes) }
            }
        } else {
            Haptics.error()
            mistakes += 1
            let flash: Set<String> = ["georgian-\(l)", "other-\(r)"]
            withAnimation(.linear(duration: 0.4)) { wrongFlash = flash }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                wrongFlash = []
                withMotion { pickedLeft = nil; pickedRight = nil }
            }
        }
    }
}

/// Build a sentence from word tiles, or spell a word from letter tiles. Tiles fly from the
/// bank to the answer line and back.
struct TilesExerciseView: View {
    let tiles: Tiles
    @Binding var chosen: [Int]
    let revealed: Evaluation?
    @Namespace private var space
    @Environment(LearningStore.self) private var store

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text(tiles.prompt)
                    .font(.titleBold)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                if let d = tiles.promptDetail {
                    Text(d).font(.headlineRounded).foregroundStyle(Palette.inkSoft)
                }
            }
            .promptCard()

            // The answer line.
            FlowLayout(spacing: tiles.isSpelling ? 6 : 8) {
                ForEach(chosen, id: \.self) { i in
                    tileButton(i, inAnswer: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: tiles.isSpelling ? 78 : 64)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(answerBorder, style: StrokeStyle(lineWidth: 2, dash: chosen.isEmpty ? [6, 6] : []))
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(tr("Your answer"))

            // The bank.
            FlowLayout(spacing: tiles.isSpelling ? 6 : 8) {
                ForEach(tiles.bank.indices, id: \.self) { i in
                    if chosen.contains(i) {
                        placeholder(i)
                    } else {
                        tileButton(i, inAnswer: false)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var answerBorder: Color {
        guard let revealed else { return Palette.line }
        return revealed.verdict == .wrong ? Palette.error : Palette.success
    }

    private func label(_ i: Int) -> some View {
        VStack(spacing: 0) {
            Text(tiles.bank[i])
                .font(.system(size: tiles.isSpelling ? 28 : 20, weight: .semibold))
                .foregroundStyle(Palette.ink)
            if tiles.isSpelling {
                Text(store.curriculum.latin(tiles.bank[i]))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.horizontal, tiles.isSpelling ? 12 : 14)
        .padding(.vertical, 10)
        .frame(minWidth: tiles.isSpelling ? 48 : 0, minHeight: 48)
    }

    private func tileButton(_ i: Int, inAnswer: Bool) -> some View {
        Button {
            guard revealed == nil else { return }
            Haptics.tap()
            withMotion(Motion.spring) {
                if inAnswer { chosen.removeAll { $0 == i } } else { chosen.append(i) }
            }
        } label: {
            label(i)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.line).offset(y: 3))
        }
        .buttonStyle(.pressable)
        .matchedGeometryEffect(id: i, in: space)
        .accessibilityIdentifier(inAnswer ? "answer-tile-\(i)" : "tile-\(i)")
        .accessibilityLabel(tiles.bank[i])
    }

    private func placeholder(_ i: Int) -> some View {
        label(i)
            .opacity(0)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.line.opacity(0.6)))
            .accessibilityHidden(true)
    }
}

/// A card to flip: Georgian on the front, English on the back, then say whether you knew it.
struct FlashcardExerciseView: View {
    let card: Flashcard
    let revealed: Evaluation?
    let onRecall: (Bool) -> Void
    @State private var flipped = false

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                face(front: true).opacity(flipped ? 0 : 1)
                face(front: false).opacity(flipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .onTapGesture { flip() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(flipped ? "" : tr("Shows the meaning"))
            .accessibilityAction { flip() }
            .accessibilityIdentifier("flashcard")

            if flipped && revealed == nil {
                HStack(spacing: 12) {
                    Button(tr("Still learning")) { onRecall(false) }
                        .buttonStyle(SoftButtonStyle())
                        .accessibilityIdentifier("recall-no")
                    Button(tr("I knew it")) { onRecall(true) }
                        .buttonStyle(ChunkyButtonStyle(color: .tkemali))
                        .accessibilityIdentifier("recall-yes")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if !flipped {
                Button(tr("Show the meaning")) { flip() }
                    .buttonStyle(SoftButtonStyle())
                    .accessibilityIdentifier("flip")
            }
        }
    }

    private func flip() {
        guard !flipped else { return }
        Haptics.tap()
        withMotion(Motion.spring) { flipped = true }
    }

    private func face(front: Bool) -> some View {
        VStack(spacing: 10) {
            if front {
                GeorgianText(card.front, size: 46, weight: .bold, color: .white)
                Text(card.frontLatin).font(.headlineRounded).foregroundStyle(.white.opacity(0.85))
                SpeakerButton(text: card.front, size: 38)
            } else {
                Text(card.back).font(.titleBold).foregroundStyle(.white).multilineTextAlignment(.center)
                GeorgianText(card.front, size: 24, color: .white.opacity(0.9))
                if let n = card.note {
                    Text(n).font(.calloutRounded).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(front ? BrandColor.saperavi.gradient : BrandColor.tkemali.gradient)
                .shadow(color: Palette.saperavi.opacity(0.3), radius: 18, y: 10)
        )
    }
}
