import SwiftUI

/// Text styles. Everything follows the iPhone's text size (Dynamic Type): the styles are
/// built on Apple's text styles, and big Georgian letters use `@ScaledMetric` sizes.
/// Georgian is drawn by the system's Georgian font; the rounded design applies to Latin text.
extension Font {
    static let display = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let titleBold = Font.system(.title, design: .rounded, weight: .bold)
    static let title2Bold = Font.system(.title2, design: .rounded, weight: .bold)
    static let headlineRounded = Font.system(.headline, design: .rounded, weight: .semibold)
    static let bodyRounded = Font.system(.body, design: .rounded)
    static let calloutRounded = Font.system(.callout, design: .rounded)
    static let captionBold = Font.system(.caption, design: .rounded, weight: .bold)

    /// Georgian at a given size, scaled with the text size setting.
    static func georgian(_ size: CGFloat, weight: Font.Weight = .semibold, relativeTo style: Font.TextStyle = .title) -> Font {
        .system(size: size, weight: weight).leading(.loose)
    }
}

/// Georgian text that is never squeezed or clipped: Mkhedruli has tall ascenders and
/// descenders, so it gets room above and below and scales down rather than cutting.
struct GeorgianText: View {
    let text: String
    @ScaledMetric private var size: CGFloat
    var weight: Font.Weight = .semibold
    var color: Color = Palette.ink

    init(_ text: String, size: CGFloat = 28, weight: Font.Weight = .semibold, color: Color = Palette.ink) {
        self.text = text
        _size = ScaledMetric(wrappedValue: size, relativeTo: .title)
        self.weight = weight
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
            .lineSpacing(size * 0.15)
            .padding(.vertical, size * 0.08)
            .minimumScaleFactor(0.5)
            .multilineTextAlignment(.center)
            .environment(\.locale, Locale(identifier: "ka_GE"))
    }
}
