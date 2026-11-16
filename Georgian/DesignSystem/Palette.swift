import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    /// A colour with its own light and dark version.
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    init(hex: UInt32) { self.init(UIColor(hex: hex)) }
}

/// The app's colours, named after Georgia: pomegranate red, Saperavi wine purple, the gold
/// of church enamel, green tkemali plums and the Black Sea. Each has a light and a dark
/// version chosen for contrast on the backgrounds below.
enum Palette {
    // Surfaces
    static let background = Color.adaptive(0xFFF7EF, 0x120E18)
    static let backgroundDeep = Color.adaptive(0xFCEBDD, 0x0B0810)
    static let surface = Color.adaptive(0xFFFFFF, 0x1E1828)
    static let surfaceRaised = Color.adaptive(0xFFF1E4, 0x2A2236)
    static let line = Color.adaptive(0xEEDFD2, 0x382E45)

    // Text
    static let ink = Color.adaptive(0x24182A, 0xF8F2EC)
    static let inkSoft = Color.adaptive(0x6B5A6E, 0xBDB1C2)
    static let inkFaint = Color.adaptive(0x9C8C9E, 0x8A7E91)

    // Brand
    static let pomegranate = Color.adaptive(0xE23B4E, 0xFF5D6E)
    static let saperavi = Color.adaptive(0x7A3BC2, 0xB07CF0)
    static let gold = Color.adaptive(0xF0A12E, 0xFFC25C)
    static let tkemali = Color.adaptive(0x2FA45A, 0x5AD585)
    static let blacksea = Color.adaptive(0x1592AD, 0x3FC6E0)

    // Meaning
    static let success = tkemali
    static let error = Color.adaptive(0xE5484D, 0xFF6B6F)
    static let flame = Color.adaptive(0xFF7A1A, 0xFF9A45)
}

/// A brand colour by name, as the course data names them.
enum BrandColor: String, CaseIterable {
    case pomegranate, saperavi, gold, tkemali, blacksea

    init(named name: String) { self = BrandColor(rawValue: name) ?? .pomegranate }

    var color: Color {
        switch self {
        case .pomegranate: return Palette.pomegranate
        case .saperavi: return Palette.saperavi
        case .gold: return Palette.gold
        case .tkemali: return Palette.tkemali
        case .blacksea: return Palette.blacksea
        }
    }

    /// The darker edge under a raised button.
    var deep: Color {
        switch self {
        case .pomegranate: return Color.adaptive(0xA9213A, 0xC23347)
        case .saperavi: return Color.adaptive(0x55248F, 0x7E4FC0)
        case .gold: return Color.adaptive(0xB9740F, 0xC98F2C)
        case .tkemali: return Color.adaptive(0x1D7A40, 0x2F9F5B)
        case .blacksea: return Color.adaptive(0x0D6A80, 0x2393A9)
        }
    }

    /// The partner colour for gradients.
    var partner: Color {
        switch self {
        case .pomegranate: return Palette.saperavi
        case .saperavi: return Palette.blacksea
        case .gold: return Palette.pomegranate
        case .tkemali: return Palette.blacksea
        case .blacksea: return Palette.tkemali
        }
    }

    /// Text on top of the colour: dark on gold, white on the rest.
    var onColor: Color { self == .gold ? Color(hex: 0x2A1A06) : .white }

    var gradient: LinearGradient {
        LinearGradient(colors: [color, partner], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum Gradients {
    static let hero = LinearGradient(colors: [Palette.pomegranate, Palette.saperavi], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let gold = LinearGradient(colors: [Palette.gold, Palette.flame], startPoint: .top, endPoint: .bottom)
    static let success = LinearGradient(colors: [Palette.tkemali, Palette.blacksea], startPoint: .topLeading, endPoint: .bottomTrailing)
}
