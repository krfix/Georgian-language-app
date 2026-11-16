import SwiftUI

extension View {
    /// A card: white (or deep purple at night) with soft corners and a soft shadow.
    func card(padding: CGFloat = 18, cornerRadius: CGFloat = 24) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Palette.surface)
                    .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 6)
            )
    }

    /// A card filled with a brand gradient.
    func gradientCard(_ color: BrandColor, padding: CGFloat = 20, cornerRadius: CGFloat = 28) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(color.gradient)
                    // Soft light in one corner.
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(RadialGradient(colors: [.white.opacity(0.28), .clear], center: .topTrailing, startRadius: 0, endRadius: 240))
                }
                .shadow(color: color.fill.opacity(0.35), radius: 18, x: 0, y: 10)
            )
    }
}

/// A heading above a group of cards.
struct SectionTitle: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title2Bold)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing, let action {
                Button(trailing, action: action)
                    .font(.calloutRounded.weight(.semibold))
                    .foregroundStyle(Palette.pomegranate)
            }
        }
        .padding(.top, 8)
    }
}

/// A small coloured label: "Learned", "+10 XP".
struct Pill: View {
    let text: String
    var color: Color = Palette.pomegranate
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).imageScale(.small) }
            Text(text)
        }
        .font(.captionBold)
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.14)))
    }
}

/// A number with an icon and a label underneath: streak, XP, level.
struct StatTile: View {
    let symbol: String
    let value: String
    let label: String
    var color: Color = Palette.pomegranate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(color.opacity(0.15)))
            Text(value)
                .font(.title2Bold)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.calloutRounded)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(2)
        }
        .card(padding: 14, cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}

/// The screen background: warm paper with a few soft colour glows.
struct AmbientBackground: View {
    var tint: BrandColor = .pomegranate

    var body: some View {
        ZStack {
            Palette.background
            GeometryReader { geo in
                Circle()
                    .fill(tint.color.opacity(0.16))
                    .frame(width: geo.size.width * 0.9)
                    .blur(radius: 70)
                    .offset(x: geo.size.width * 0.45, y: -geo.size.width * 0.35)
                Circle()
                    .fill(tint.partner.opacity(0.12))
                    .frame(width: geo.size.width * 0.8)
                    .blur(radius: 80)
                    .offset(x: -geo.size.width * 0.35, y: geo.size.height * 0.55)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
