import SwiftUI
import UIKit

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

/// Georgian at the largest size where no word has to break: SwiftUI splits a word that is
/// wider than the line (გამიჩერე / თ), so the size is worked out from the widest word.
enum GeorgianFit {
    /// The largest size from `maxSize` down to `minSize` (in steps of 2) at which every word
    /// fits on one line `width` wide and, when `height` is given, the whole text fits in it.
    static func size(for text: String, weight: UIFont.Weight = .bold, maxSize: CGFloat, minSize: CGFloat,
                     width: CGFloat, height: CGFloat? = nil, lineSpacing: CGFloat = 0) -> CGFloat {
        guard width > 0 else { return minSize }
        let words = text.split(separator: " ").map(String.init)
        var size = maxSize
        while size > minSize {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let widest = words.map { ($0 as NSString).size(withAttributes: attrs).width }.max() ?? 0
            if widest <= width * 0.96 {
                guard let height else { return size }
                let rect = (text as NSString).boundingRect(with: CGSize(width: width * 0.96, height: .greatestFiniteMagnitude),
                                                           options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                let lines = (rect.height / font.lineHeight).rounded(.up)
                if rect.height + lines * lineSpacing <= height { return size }
            }
            size -= 2
        }
        return minSize
    }
}

/// Large Georgian on a card that never breaks inside a word: it measures the space it has
/// and takes the largest size (up to `maxSize`, scaled with the text size setting) that fits.
struct FittedGeorgianText: View {
    let text: String
    @ScaledMetric private var maxSize: CGFloat
    var color: Color
    @State private var width: CGFloat = 300

    init(_ text: String, maxSize: CGFloat = 40, color: Color = Palette.ink) {
        self.text = text
        _maxSize = ScaledMetric(wrappedValue: maxSize, relativeTo: .title)
        self.color = color
    }

    var body: some View {
        let size = GeorgianFit.size(for: text, maxSize: maxSize, minSize: 16, width: width)
        Text(text)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
            .lineSpacing(size * 0.12)
            .padding(.vertical, size * 0.08)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { width = g.size.width }
                    .onChange(of: g.size.width) { _, w in width = w }
            })
            .environment(\.locale, Locale(identifier: "ka_GE"))
    }
}
