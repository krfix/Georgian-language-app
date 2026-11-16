import SwiftUI

/// Multiple choice, letter recognition, reading, missing letter, fill-in and listening:
/// one prompt and a set of options.
struct ChoiceExerciseView: View {
    let choice: Choice
    let kind: ExerciseKind
    @Binding var selection: Int?
    let revealed: Evaluation?
    @Environment(AudioService.self) private var audio

    var body: some View {
        VStack(spacing: 22) {
            prompt
            Spacer(minLength: 0)
            options
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            if kind == .listening, let text = choice.audioText { audio.play(text) }
        }
    }

    @ViewBuilder private var prompt: some View {
        VStack(spacing: 10) {
            if kind == .listening, let text = choice.audioText {
                Button {
                    Haptics.tap()
                    audio.play(text)
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 110, height: 110)
                        .background(Circle().fill(Gradients.success))
                        .symbolEffect(.variableColor.iterative, isActive: audio.isPlaying(text))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Play again")
                Button("Slower") { audio.play(text, slow: true) }
                    .font(.calloutRounded.weight(.semibold))
                if revealed != nil {
                    GeorgianText(text, size: 28)
                }
            } else if choice.promptIsGeorgian {
                GeorgianText(choice.prompt, size: promptSize, weight: .bold)
                    .accessibilityIdentifier("prompt")
                // Hearing a letter or a word to read would give the answer away: only afterwards.
                if !choice.prompt.contains("_") && (revealed != nil || ![.letterRecognition, .reading].contains(kind)) {
                    SpeakerButton(text: choice.prompt, size: 38)
                }
            } else {
                Text(choice.prompt)
                    .font(choice.prompt.count <= 6 ? .system(size: 56, weight: .heavy, design: .rounded) : .titleBold)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("prompt")
            }
            if let d = choice.promptDetail {
                Text(d)
                    .font(.calloutRounded)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .promptCard()
    }

    private var promptSize: CGFloat {
        let n = choice.prompt.count
        return n <= 2 ? 96 : n <= 8 ? 48 : n <= 16 ? 34 : 26
    }

    /// Four short answers go in a 2×2 grid; Georgian needs a narrower limit (its letters are
    /// wider and are drawn bigger), so a long word gets a full-width row instead of wrapping.
    private var useGrid: Bool {
        let limit = choice.optionsAreGeorgian ? 6 : 10
        return choice.options.count == 4 && choice.options.allSatisfy { $0.text.count <= limit }
    }

    @ViewBuilder private var options: some View {
        if useGrid {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(choice.options.enumerated()), id: \.element.id) { position, option in
                    OptionTile(option: option, georgian: choice.optionsAreGeorgian, large: true,
                               state: state(of: option), position: position) { pick(option) }
                }
            }
        } else {
            VStack(spacing: 12) {
                ForEach(Array(choice.options.enumerated()), id: \.element.id) { position, option in
                    OptionTile(option: option, georgian: choice.optionsAreGeorgian, large: false,
                               state: state(of: option), position: position) { pick(option) }
                }
            }
        }
    }

    private func pick(_ option: ChoiceOption) {
        guard revealed == nil else { return }
        Haptics.select()
        withMotion(Motion.spring) { selection = option.id }
    }

    private func state(of option: ChoiceOption) -> OptionTile.State {
        if revealed != nil {
            if option.id == choice.answer { return .right }
            if option.id == selection { return .wrong }
            return .faded
        }
        return option.id == selection ? .selected : .normal
    }
}

/// One answer to tap.
struct OptionTile: View {
    enum State { case normal, selected, right, wrong, faded }

    let option: ChoiceOption
    let georgian: Bool
    let large: Bool
    let state: State
    let position: Int
    let action: () -> Void

    private var border: Color {
        switch state {
        case .selected: return Palette.blacksea
        case .right: return Palette.success
        case .wrong: return Palette.error
        default: return Palette.line
        }
    }

    private var fill: Color {
        switch state {
        case .selected: return Palette.blacksea.opacity(0.12)
        case .right: return Palette.success.opacity(0.16)
        case .wrong: return Palette.error.opacity(0.14)
        default: return Palette.surface
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if georgian {
                    // One line that shrinks to fit: a word never breaks in the middle.
                    GeorgianText(option.text, size: large ? 34 : 24, weight: .semibold)
                        .lineLimit(large ? 1 : 3)
                } else {
                    Text(option.text)
                        .font(large ? .system(.title2, design: .rounded, weight: .bold) : .headlineRounded)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let d = option.detail, state != .normal && state != .selected || !large {
                    Text(d).font(.caption).foregroundStyle(Palette.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, minHeight: large ? 92 : 58)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(border, lineWidth: state == .normal || state == .faded ? 2 : 3))
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(border.opacity(0.6)).offset(y: 3))
            .opacity(state == .faded ? 0.5 : 1)
            .scaleEffect(state == .selected ? 1.03 : 1)
            .modifier(Shake(amount: state == .wrong ? 1 : 0))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("option-\(position)")
        .accessibilityAddTraits(state == .selected ? .isSelected : [])
        .accessibilityHint(state == .right ? "Right answer" : state == .wrong ? "Your answer, wrong" : "")
    }
}

/// A short side-to-side shake for a wrong answer.
struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4), y: 0))
    }
}

/// Typing the English meaning.
struct TypingExerciseView: View {
    let typing: Typing
    @Binding var text: String
    let revealed: Evaluation?
    let onSubmit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                GeorgianText(typing.prompt, size: typing.prompt.count <= 10 ? 48 : 32, weight: .bold)
                Text(typing.promptLatin).font(.headlineRounded).foregroundStyle(Palette.inkSoft)
                SpeakerButton(text: typing.prompt, size: 38)
            }
            .promptCard()

            TextField("Type in English", text: $text)
                .font(.title3.weight(.semibold))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .disabled(revealed != nil)
                .onSubmit { if !text.isEmpty { onSubmit() } }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(revealed == nil ? (focused ? Palette.blacksea : Palette.line) : (revealed!.verdict == .wrong ? Palette.error : Palette.success), lineWidth: 2.5))
                .accessibilityIdentifier("answer-field")
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true } }
    }
}

/// A conversation: the lines so far as chat bubbles, then your reply to choose.
struct DialogueExerciseView: View {
    let turn: DialogueTurn
    @Binding var selection: Int?
    let revealed: Evaluation?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(turn.history.suffix(4).enumerated()), id: \.offset) { _, line in
                Bubble(line: line, partner: turn.partner)
            }
            if revealed != nil {
                Bubble(line: turn.line, partner: turn.partner)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Divider().padding(.vertical, 4)
            VStack(spacing: 10) {
                ForEach(Array(turn.options.enumerated()), id: \.offset) { i, text in
                    OptionTile(option: ChoiceOption(id: i, text: text, detail: nil), georgian: true, large: false,
                               state: state(i), position: i) {
                        guard revealed == nil else { return }
                        Haptics.select()
                        withMotion { selection = i }
                    }
                }
            }
        }
    }

    private func state(_ i: Int) -> OptionTile.State {
        if revealed != nil {
            if i == turn.answer { return .right }
            return i == selection ? .wrong : .faded
        }
        return i == selection ? .selected : .normal
    }
}

struct Bubble: View {
    let line: DialogueLine
    let partner: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if line.isLearner { Spacer(minLength: 40) }
            if !line.isLearner {
                Text(String(line.speaker.prefix(1)))
                    .font(.headlineRounded)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Palette.saperavi))
                    .accessibilityHidden(true)
            }
            VStack(alignment: line.isLearner ? .trailing : .leading, spacing: 3) {
                Text(line.ka).font(.system(.body, weight: .semibold)).foregroundStyle(line.isLearner ? .white : Palette.ink)
                Text(line.en).font(.caption).foregroundStyle(line.isLearner ? .white.opacity(0.8) : Palette.inkSoft)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(line.isLearner ? AnyShapeStyle(Palette.blacksea) : AnyShapeStyle(Palette.surface))
            )
            HStack(spacing: 0) {
                SpeakerButton(text: line.ka, size: 30)
            }
            if !line.isLearner { Spacer(minLength: 20) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.isLearner ? "You" : line.speaker): \(line.ka), \(line.en)")
    }
}
