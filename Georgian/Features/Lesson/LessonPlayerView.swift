import SwiftUI

/// The full-screen lesson: progress at the top, the exercise in the middle, Check or the
/// feedback at the bottom, and the reward when it's done.
struct LessonPlayerView: View {
    let request: SessionRequest
    @Environment(LearningStore.self) private var store
    @Environment(AudioService.self) private var audio
    @Environment(\.dismiss) private var dismiss
    @State private var model: LessonPlayerModel?
    @State private var confirmQuit = false

    var body: some View {
        ZStack {
            AmbientBackground(tint: tint)
            if let model {
                content(model)
            }
        }
        .onAppear {
            if model == nil {
                let m = LessonPlayerModel(request: request, store: store, audio: audio)
                if LaunchOptions.current.screen == "complete" { m.showSampleReward() }
                if LaunchOptions.current.screen == "exercise", let kind = LaunchOptions.current.kind { m.skip(toKind: kind) }
                model = m
            }
        }
        .onDisappear { audio.stop() }
        .environment(\.lessonTint, tint)
    }

    private var tint: BrandColor {
        if case .lesson(let l) = request.mode, let m = store.curriculum.module(of: l.id) { return BrandColor(named: m.color) }
        if case .dialogue(_, let color) = request.mode { return BrandColor(named: color) }
        return .saperavi
    }

    @ViewBuilder private func content(_ model: LessonPlayerModel) -> some View {
        if case .finished(let reward) = model.phase {
            LessonCompleteView(reward: reward, title: model.title, isReview: model.isReview, isDialogue: model.isDialogue) { dismiss() }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else {
            VStack(spacing: 0) {
                topBar(model)
                if let ex = model.current {
                    GeometryReader { geo in
                        ScrollView {
                            ExerciseView(exercise: ex, model: model)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .padding(.bottom, 16)
                                .frame(minHeight: geo.size.height, alignment: .top)
                                .id(ex.id)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                        removal: .move(edge: .leading).combined(with: .opacity)))
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .scrollBounceBehavior(.basedOnSize)
                    }
                    BottomBar(exercise: ex, model: model, tint: tint)
                }
            }
            .confirmationDialog(tr("Leave this lesson?"), isPresented: $confirmQuit, titleVisibility: .visible) {
                Button(tr("Leave"), role: .destructive) { dismiss() }
                Button(tr("Keep learning"), role: .cancel) {}
            } message: {
                Text(tr("Your answers so far are saved, but the lesson won't count as finished."))
            }
        }
    }

    private func topBar(_ model: LessonPlayerModel) -> some View {
        HStack(spacing: 14) {
            CircleIconButton(symbol: "xmark", label: tr("Close")) {
                if model.session.answered > 0 { confirmQuit = true } else { dismiss() }
            }
            .accessibilityIdentifier("lesson-close")
            ProgressBar(progress: model.session.progress, color: tint.color, height: 16)
            if model.combo >= 3 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                    Text("\(model.combo)").contentTransition(.numericText())
                }
                .font(.captionBold)
                .foregroundStyle(Palette.flame)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(tr("{0} right in a row", model.combo))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .motion(Motion.bouncy, value: model.combo >= 3)
    }
}

/// Check, or the feedback with Continue.
private struct BottomBar: View {
    let exercise: Exercise
    @Bindable var model: LessonPlayerModel
    let tint: BrandColor

    var body: some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .feedback(let evaluation):
                FeedbackPanel(evaluation: evaluation) { withMotion { model.next() } }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            default:
                VStack {
                    if !exercise.isGraded {
                        Button(tr("Continue")) { Haptics.tap(); withMotion { model.next() } }
                            .buttonStyle(ChunkyButtonStyle(color: tint))
                            .accessibilityIdentifier("lesson-continue")
                    } else if showsCheck {
                        Button(tr("Check")) { model.check() }
                            .buttonStyle(ChunkyButtonStyle(color: tint, isEnabled: model.canCheck))
                            .disabled(!model.canCheck)
                            .accessibilityIdentifier("lesson-check")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .motion(Motion.spring, value: model.phase)
    }

    /// Matching and flashcards answer themselves.
    private var showsCheck: Bool {
        switch exercise.content {
        case .matching, .flashcard: return false
        default: return true
        }
    }
}

/// Green for right, red for wrong, with the right answer and why.
struct FeedbackPanel: View {
    let evaluation: Evaluation
    let onContinue: () -> Void
    @State private var praise = [tr("Brilliant!"), tr("Great job!"), tr("ყოჩაღ! Well done!"), tr("Perfect!"), tr("Spot on!"), tr("Excellent!")].randomElement()!

    private var color: Color {
        switch evaluation.verdict {
        case .correct: return Palette.success
        case .almost: return Palette.gold
        case .wrong: return Palette.error
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: evaluation.verdict == .wrong ? "xmark.circle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 28, weight: .bold))
                    .symbolEffect(.bounce, value: evaluation.verdict)
                Text(title)
                    .font(.title2Bold)
            }
            .foregroundStyle(color)
            if evaluation.verdict != .correct, !evaluation.correctAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(evaluation.verdict == .almost ? tr("Watch the spelling:") : tr("Right answer:"))
                        .font(.calloutRounded.weight(.semibold))
                        .foregroundStyle(color)
                    Text(evaluation.correctAnswer)
                        .font(.headlineRounded)
                        .foregroundStyle(Palette.ink)
                }
            }
            if let e = evaluation.explanation, !e.isEmpty, evaluation.verdict != .correct || e.count < 90 {
                Text(e)
                    .font(.calloutRounded)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(tr("Continue"), action: { Haptics.tap(); onContinue() })
                .buttonStyle(ChunkyButtonStyle(color: evaluation.verdict == .wrong ? .pomegranate : (evaluation.verdict == .almost ? .gold : .tkemali)))
                .accessibilityIdentifier("lesson-continue")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(color.opacity(0.14))
                .background(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous).fill(Palette.surface))
                .ignoresSafeArea(edges: .bottom)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feedback")
    }

    private var title: String {
        switch evaluation.verdict {
        case .correct: return praise
        case .almost: return tr("Almost!")
        case .wrong: return tr("Not quite")
        }
    }
}
