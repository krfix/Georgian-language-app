import SwiftUI

/// The main button: a raised, rounded tile in a brand colour that presses down when tapped.
struct ChunkyButtonStyle: ButtonStyle {
    var color: BrandColor = .pomegranate
    var isEnabled = true
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        let depth: CGFloat = pressed ? 1 : 5
        return configuration.label
            .font(.headlineRounded)
            .foregroundStyle(isEnabled ? color.onColor : Palette.inkFaint)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? AnyShapeStyle(color.color) : AnyShapeStyle(Palette.line))
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? color.deep : Palette.line.opacity(0.7))
                    .offset(y: depth)
            )
            .offset(y: pressed ? 4 : 0)
            .padding(.bottom, 5)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// A quieter raised button on the surface colour, with an outline.
struct SoftButtonStyle: ButtonStyle {
    var height: CGFloat = 50

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.headlineRounded)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line, lineWidth: 2))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.line).offset(y: pressed ? 1 : 4)
            )
            .offset(y: pressed ? 3 : 0)
            .padding(.bottom, 4)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
            .contentShape(Rectangle())
    }
}

/// A button that shrinks a little when pressed: for cards and tiles.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// A round icon button (close, play).
struct CircleIconButton: View {
    let symbol: String
    var color: Color = Palette.inkSoft
    var label: String
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Palette.surfaceRaised))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }
}
