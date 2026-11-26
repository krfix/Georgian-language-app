import UIKit

/// Taps and buzzes, off when the learner turns haptics off in Profile.
@MainActor
enum Haptics {
    static var enabled = true

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A firmer knock: a hold that worked (a letter's card opening).
    static func press() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func select() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func celebrate() {
        guard enabled else { return }
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { g.impactOccurred(intensity: 0.7) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { g.impactOccurred(intensity: 0.4) }
    }
}
