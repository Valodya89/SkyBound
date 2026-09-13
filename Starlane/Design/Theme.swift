import SwiftUI
import UIKit
import CoreText
import StarlaneCore

/// "Flight deck" design tokens. One warm signal colour (flare) for anything the player can act on, one cold
/// data colour (ice) for gems and information, gold only as the coin mark and premium. Everything else is ink
/// on a dark deck.
enum Theme {
    // Surfaces
    static let bg = Color(hex: "#0B0E14")
    static let panel = Color(hex: "#12161F")
    static let panel2 = Color(hex: "#181E2A")
    static let panel3 = Color(hex: "#202836")
    static let line = Color(hex: "#232A38")
    static let line2 = Color(hex: "#323B4D")

    // Text
    static let text = Color(hex: "#EEF1F5")
    static let muted = Color(hex: "#98A3B6")
    static let faint = Color(hex: "#7A869A")

    // Signal colours
    static let flare = Color(hex: "#F97B2F")
    static let flareDeep = Color(hex: "#B9521B")
    static let flareInk = Color(hex: "#1A0C05")
    static let ice = Color(hex: "#7EDCF2")
    static let iceInk = Color(hex: "#062028")
    static let gold = Color(hex: "#F2B544")
    static let goldDeep = Color(hex: "#A9731B")

    // Geometry
    static let radius: CGFloat = 6
    static let radiusSmall: CGFloat = 4

    /// Scene background, also used behind the SpriteKit view before the scene exists.
    static let ink = bg
}

extension Color {
    init(hex: String, alpha: Double = 1) {
        let c = RGBA(hex: hex, alpha: alpha)
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }

    init(_ rgba: RGBA) {
        self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }

    static func rarity(_ r: Rarity) -> Color { Color(hex: r.colorHex) }
}

/// Bundled variable fonts (Big Shoulders Display for numerals and titles, Instrument Sans for copy), resolved
/// through CoreText variation axes so every weight comes from one file. Falls back to the compressed system
/// font if the bundle is missing them.
enum GameFont {
    private static let weightAxis = 2003265652 // 'wght'
    private static var cache: [String: UIFont] = [:]
    private static let variationKey = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)

    static func display(_ size: CGFloat, weight: CGFloat = 900) -> UIFont {
        resolve(family: "Big Shoulders Display", size: size, weight: weight) {
            UIFont.systemFont(ofSize: size, weight: .black, width: .compressed)
        }
    }

    static func body(_ size: CGFloat, weight: CGFloat = 400) -> UIFont {
        resolve(family: "Instrument Sans", size: size, weight: weight) {
            UIFont.systemFont(ofSize: size, weight: weight >= 700 ? .bold : weight >= 600 ? .semibold : weight >= 500 ? .medium : .regular)
        }
    }

    private static func resolve(family: String, size: CGFloat, weight: CGFloat, fallback: () -> UIFont) -> UIFont {
        let key = "\(family)|\(size)|\(weight)"
        if let f = cache[key] { return f }
        let font: UIFont
        if UIFont.familyNames.contains(family) {
            let descriptor = UIFontDescriptor(fontAttributes: [
                .family: family,
                variationKey: [weightAxis: weight],
            ])
            font = UIFont(descriptor: descriptor, size: size)
        } else {
            font = fallback()
        }
        cache[key] = font
        return font
    }
}

extension Font {
    /// Condensed display face for every number, title and button.
    static func display(_ size: CGFloat, weight: CGFloat = 900) -> Font {
        Font(GameFont.display(size, weight: weight))
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font(GameFont.body(size, weight: weight.axisValue))
    }
}

extension Font.Weight {
    var axisValue: CGFloat {
        switch self {
        case .black: 900
        case .heavy: 800
        case .bold: 700
        case .semibold: 600
        case .medium: 500
        default: 400
        }
    }
}

extension View {
    /// Uppercase tracked label: 10.5 / 600 / .12em by default.
    func capsLabel(_ size: CGFloat = 10.5, color: Color = Theme.muted, tracking: CGFloat? = nil) -> some View {
        self.font(.body(size, weight: .semibold))
            .tracking(tracking ?? size * 0.12)
            .foregroundStyle(color)
            .textCase(.uppercase)
            .lineLimit(1)
    }

    /// Big Shoulders Display, uppercase.
    func display(_ size: CGFloat, color: Color = Theme.text) -> some View {
        self.font(.display(size))
            .foregroundStyle(color)
            .textCase(.uppercase)
            .lineLimit(1)
    }
}
