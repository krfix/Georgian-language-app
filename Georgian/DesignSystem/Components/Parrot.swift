import SwiftUI

/// Ara, the app's mascot: a scarlet macaw with the same head as the app icon (drawn by
/// tools/brand/make_brand.py; docs/brand.md). Its moods change only the eye, the head's tilt
/// and the wing, so Ara always looks like the same character. It bobs gently and, when
/// saying hello, blinks now and then; with Reduce Motion on it stays still.
struct ParrotView: View {
    enum Mood {
        /// Welcome, onboarding, "nothing here yet".
        case hello
        /// Lesson finished, milestones: eyes smiling, wing up.
        case cheer
        /// Tips and "nothing found": head tilted, looking up.
        case think
        /// "All caught up": eyes closed.
        case sleep

        var imageName: String {
            switch self {
            case .hello: return "Parrot"
            case .cheer: return "ParrotCheer"
            case .think: return "ParrotThink"
            case .sleep: return "ParrotSleep"
            }
        }

        var label: String {
            switch self {
            case .hello: return tr("Ara the parrot")
            case .cheer: return tr("Ara the parrot, cheering")
            case .think: return tr("Ara the parrot, thinking")
            case .sleep: return tr("Ara the parrot, asleep")
            }
        }
    }

    var height: CGFloat = 160
    var mood: Mood = .hello
    var bobbing = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false
    @State private var blinking = false

    var body: some View {
        Image(blinking && mood == .hello ? "ParrotBlink" : mood.imageName)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .rotationEffect(.degrees(up ? -3 : 3), anchor: .bottom)
            .offset(y: up ? -4 : 2)
            .shadow(color: Palette.pomegranate.opacity(0.22), radius: 16, y: 10)
            .onAppear {
                guard bobbing && !reduceMotion else { return }
                withAnimation(.easeInOut(duration: mood == .sleep ? 2.4 : 1.4).repeatForever(autoreverses: true)) { up = true }
            }
            .task(id: mood == .hello && !reduceMotion) {
                guard mood == .hello && !reduceMotion else { return }
                // A blink every few seconds: closed for a sixth of a second.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 3.0...5.5)))
                    if Task.isCancelled { break }
                    blinking = true
                    try? await Task.sleep(for: .milliseconds(160))
                    blinking = false
                }
            }
            .accessibilityElement()
            .accessibilityLabel(mood.label)
    }
}

/// The Ara symbol (the app icon's mark, without its background): for small brand moments
/// such as the About line in Profile.
struct AraSymbol: View {
    var size: CGFloat = 44

    var body: some View {
        Image("AraSymbol")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
