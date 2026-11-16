import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// The app's colours: dark only, on pure black (OLED pixels off), as in the Logbook app.
enum Theme {
    static let bg = Color(hex: 0x000000)
    static let card = Color(hex: 0x15181D)
    static let card2 = Color(hex: 0x1C2027)
    static let selected = Color(hex: 0x2B313A)
    static let line = Color(hex: 0x262B33)
    static let text = Color(hex: 0xF2F4F7)
    static let mute = Color(hex: 0x8A93A1)
    /// Georgian red, from the flag, softened to read well on black.
    static let accent = Color(hex: 0xFF5C5C)
    static let ok = Color(hex: 0x4ADE80)
    static let bad = Color(hex: 0xF87171)
}

/// Small uppercase label above values ("LEARNED").
struct Caption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.app(11, weight: .medium))
            .tracking(0.6)
            .foregroundStyle(Theme.mute)
    }
}

extension View {
    /// A card: dark tile, corners of 20.
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// The two animation speeds (as in the Logbook app): 0.7 s for anything to watch,
/// 0.3 s for anything that follows the finger.
enum Motion {
    static let standard = Animation.easeInOut(duration: 0.7)
    static let quick = Animation.easeInOut(duration: 0.3)
}
