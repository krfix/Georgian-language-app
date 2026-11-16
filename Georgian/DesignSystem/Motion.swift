import SwiftUI

/// The app's animations. Every one goes through here so Reduce Motion is respected:
/// with it on, things change with a short fade instead of moving.
enum Motion {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.72)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.55)
    static let gentle = Animation.easeInOut(duration: 0.35)
    static let slow = Animation.easeInOut(duration: 0.8)
}

extension View {
    /// Animates with `animation`, or a plain fade when Reduce Motion is on.
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduce
    let animation: Animation
    let value: V
    func body(content: Content) -> some View {
        content.animation(reduce ? .easeInOut(duration: 0.15) : animation, value: value)
    }
}

/// `withAnimation` that respects Reduce Motion.
@MainActor
func withMotion(_ animation: Animation = Motion.spring, _ body: () -> Void) {
    if UIAccessibility.isReduceMotionEnabled {
        withAnimation(.easeInOut(duration: 0.15), body)
    } else {
        withAnimation(animation, body)
    }
}
