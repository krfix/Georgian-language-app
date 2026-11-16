import SwiftUI
import UIKit

/// The letter quiz: a letter, four answers. New letters join five at a time, in alphabetical
/// order; letters missed come back more often (rules in `Services/Quiz.swift`).
struct PracticeView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var question: Quiz.Question?
    @State private var picked: Letter?
    @State private var streak = 0
    @State private var rng = SystemRandomNumberGenerator()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Practice",
                         subtitle: "\(progress.letters.knownCount) of \(Alphabet.letters.count) known · streak \(streak)")
            if let q = question {
                Spacer()
                prompt(q)
                Spacer()
                answers(q)
                next(q)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(Theme.bg)
        .onAppear { if question == nil { ask() } }
    }

    private func prompt(_ q: Quiz.Question) -> some View {
        VStack(spacing: 8) {
            Caption(q.direction == .toLatin ? "How is this written in Latin letters?" : "Which letter is this?")
            Text(q.prompt)
                .font(.app(q.direction == .toLatin ? 120 : 72, weight: .medium))
                .foregroundStyle(Theme.text)
                .contentTransition(.opacity)
            if picked != nil {
                Text("\(q.letter.char) · \(q.letter.latin) · \(q.letter.sound)")
                    .font(.app(15)).foregroundStyle(Theme.mute)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func answers(_ q: Quiz.Question) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(q.options) { option in
                Button { answer(option, q) } label: {
                    Text(q.label(option))
                        .font(.app(q.direction == .toLatin ? 24 : 40, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(fill(option, q), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(picked != nil)
            }
        }
    }

    @ViewBuilder private func next(_ q: Quiz.Question) -> some View {
        Button { withAnimation(Motion.quick) { ask() } } label: {
            Text("Next")
                .font(.app(17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(picked == nil ? 0 : 1)
        .disabled(picked == nil)
    }

    private func fill(_ option: Letter, _ q: Quiz.Question) -> Color {
        guard let picked else { return Theme.card }
        if option == q.letter { return Theme.ok.opacity(0.35) }
        if option == picked { return Theme.bad.opacity(0.35) }
        return Theme.card
    }

    private func answer(_ option: Letter, _ q: Quiz.Question) {
        let correct = option == q.letter
        progress.record(q.letter.char, correct: correct)
        streak = correct ? streak + 1 : 0
        withAnimation(Motion.quick) { picked = option }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func ask() {
        question = Quiz.question(progress.letters, after: question?.letter.char, using: &rng)
        picked = nil
    }
}
