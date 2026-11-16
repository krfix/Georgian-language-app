import SwiftUI

/// Ara, the app's parrot: a macaw whose body curls into the letter ა (drawn by
/// tools/art/parrot.py). It bobs gently, and stays still with Reduce Motion on.
struct ParrotView: View {
    var height: CGFloat = 160
    var bobbing = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    var body: some View {
        Image("Parrot")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .rotationEffect(.degrees(up ? -3 : 3), anchor: .bottom)
            .offset(y: up ? -4 : 2)
            .shadow(color: Palette.pomegranate.opacity(0.25), radius: 16, y: 10)
            .onAppear {
                guard bobbing && !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { up = true }
            }
            .accessibilityLabel("Ara the parrot")
    }
}
