import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Text that follows the iPhone's text size (Settings › Display & Brightness › Text Size).
/// At the standard size every font is exactly the size written in the code; larger settings
/// scale it up, capped at the largest non-accessibility size so the layouts still fit.
enum TextScale {
    #if canImport(UIKit)
    private(set) static var category: UIContentSizeCategory = .large
    private static var traits = UITraitCollection(preferredContentSizeCategory: .large)
    private static var cache: [CGFloat: CGFloat] = [:]

    static func set(_ size: DynamicTypeSize) {
        let c = UIContentSizeCategory(min(size, .xxxLarge))
        guard c != category else { return }
        category = c
        traits = UITraitCollection(preferredContentSizeCategory: c)
        cache = [:]
    }

    static func scaled(_ size: CGFloat) -> CGFloat {
        guard category != .large else { return size }
        if let v = cache[size] { return v }
        // Big numbers and titles grow less than body text, as in Apple's own type styles.
        let style: UIFont.TextStyle = size >= 26 ? .title1 : size >= 19 ? .title3 : size >= 14 ? .body : .footnote
        let v = UIFontMetrics(forTextStyle: style).scaledValue(for: size, compatibleWith: traits).rounded()
        cache[size] = v
        return v
    }
    #else
    static func scaled(_ size: CGFloat) -> CGFloat { size }
    #endif
}

extension Font {
    /// The app's font: a system font of `size` points at the standard text size.
    static func app(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: TextScale.scaled(size), weight: weight, design: design)
    }
}

/// Reads the text size and rebuilds the screens when it changes in Settings.
struct TextSizeRoot<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var size
    @ViewBuilder let content: Content

    var body: some View {
        #if canImport(UIKit)
        let _ = TextScale.set(size)
        #endif
        content.id(min(size, .xxxLarge))
    }
}
