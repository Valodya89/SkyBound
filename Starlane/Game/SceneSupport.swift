import SpriteKit
import UIKit
import StarlaneCore

extension SKColor {
    convenience init(_ c: RGBA) {
        self.init(red: c.r, green: c.g, blue: c.b, alpha: c.a)
    }

    convenience init(hex: String, alpha: CGFloat = 1) {
        let c = RGBA(hex: hex)
        self.init(red: c.r, green: c.g, blue: c.b, alpha: alpha)
    }
}

enum SceneFont {
    /// Heavy system font name for glyph hints (▲ ▼) that the display face does not carry.
    static let heavy: String = UIFont.systemFont(ofSize: 16, weight: .heavy).fontName

    /// Label set in the display face at an exact weight (SKLabelNode's `fontName` cannot carry a variable-font
    /// weight, so the text is attributed instead).
    static func label(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let l = SKLabelNode()
        l.attributedText = NSAttributedString(string: text, attributes: [
            .font: GameFont.display(size), .foregroundColor: color,
        ])
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .center
        return l
    }
}

/// Builds every texture procedurally at launch; the game ships with zero image assets.
final class TextureFactory {
    private var cache: [String: SKTexture] = [:]

    private func make(_ key: String, size: CGSize, scale: CGFloat = 2, _ draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let t = cache[key] { return t }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            draw(ctx.cgContext, size)
        }
        let t = SKTexture(image: image)
        t.filteringMode = .linear
        cache[key] = t
        return t
    }

    /// White SF Symbol rendered to a texture (tinted later with `color`/`colorBlendFactor`).
    func symbol(_ name: String) -> SKTexture {
        if let t = cache["symbol.\(name)"] { return t }
        let config = UIImage.SymbolConfiguration(pointSize: 64, weight: .heavy)
        let image = (UIImage(systemName: name, withConfiguration: config) ?? UIImage(systemName: "circle.fill", withConfiguration: config) ?? UIImage())
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        let t = SKTexture(image: image)
        cache["symbol.\(name)"] = t
        return t
    }

    // MARK: Gradients

    func verticalGradient(key: String, stops: [(RGBA, CGFloat)], height: CGFloat = 256) -> SKTexture {
        make(key, size: CGSize(width: 4, height: height), scale: 1) { g, size in
            let colors = stops.map { SKColor($0.0).cgColor } as CFArray
            let locs = stops.map { $0.1 }
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) else { return }
            g.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    func radialGlow(key: String, color: RGBA, inner: CGFloat = 1, size: CGFloat = 256) -> SKTexture {
        make(key, size: CGSize(width: size, height: size), scale: 1) { g, s in
            let c = SKColor(color)
            let colors = [c.withAlphaComponent(inner).cgColor, c.withAlphaComponent(0).cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            let center = CGPoint(x: s.width / 2, y: s.height / 2)
            g.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: s.width / 2, options: [])
        }
    }

    var softShadow: SKTexture {
        make("shadow", size: CGSize(width: 128, height: 40), scale: 1) { g, s in
            let colors = [SKColor.black.withAlphaComponent(0.55).cgColor, SKColor.black.withAlphaComponent(0).cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            g.saveGState()
            g.scaleBy(x: 1, y: s.height / s.width)
            let c = CGPoint(x: s.width / 2, y: s.width / 2)
            g.drawRadialGradient(grad, startCenter: c, startRadius: 0, endCenter: c, endRadius: s.width / 2, options: [])
            g.restoreGState()
        }
    }

    var dot: SKTexture {
        make("dot", size: CGSize(width: 16, height: 16)) { g, s in
            g.setFillColor(SKColor.white.cgColor)
            g.fillEllipse(in: CGRect(origin: .zero, size: s))
        }
    }

    /// Three overlapping puffs filled as one union, so semi-transparent clouds have no seams.
    var cloud: SKTexture {
        make("cloud", size: CGSize(width: 256, height: 128), scale: 1) { g, s in
            let w = s.width, h: CGFloat = 26, cy = s.height * 0.62
            g.setFillColor(SKColor.white.cgColor)
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: w * 0.5 - w * 0.5, y: cy - h, width: w, height: h * 2))
            path.addEllipse(in: CGRect(x: w * 0.5 + w * 0.22 - w * 0.28, y: cy - h * 0.42 - h * 0.78, width: w * 0.56, height: h * 1.56))
            path.addEllipse(in: CGRect(x: w * 0.5 - w * 0.25 - w * 0.24, y: cy + h * 0.14 - h * 0.66, width: w * 0.48, height: h * 1.32))
            g.addPath(path)
            g.fillPath(using: .winding)
        }
    }

    var pixel: SKTexture {
        make("pixel", size: CGSize(width: 4, height: 4), scale: 1) { g, s in
            g.setFillColor(SKColor.white.cgColor)
            g.fill(CGRect(origin: .zero, size: s))
        }
    }

    /// White texture fading from transparent (top) to opaque (bottom); tinted per biome for road edges.
    var edgeFade: SKTexture {
        make("edgeFade", size: CGSize(width: 4, height: 256), scale: 1) { g, s in
            let colors = [SKColor.white.withAlphaComponent(0).cgColor, SKColor.white.cgColor, SKColor.white.cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.25, 1]) else { return }
            g.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: s.height), options: [])
        }
    }

    // MARK: Entities (drawn in a 300-wide reference space; scaled by the scene)

    /// Asteroid: an irregular rock with a lit top-left edge.
    var wall: SKTexture {
        make("wall", size: CGSize(width: 300, height: 284)) { g, s in
            let pts: [(CGFloat, CGFloat)] = [(0.08, 0.62), (0.2, 0.22), (0.46, 0.06), (0.74, 0.12), (0.94, 0.4), (0.9, 0.78), (0.66, 0.98), (0.3, 0.94)]
            let path = CGMutablePath()
            for (i, p) in pts.enumerated() {
                let c = CGPoint(x: p.0 * s.width, y: p.1 * s.height)
                if i == 0 { path.move(to: c) } else { path.addLine(to: c) }
            }
            path.closeSubpath()
            g.addPath(path); g.setFillColor(SKColor(hex: "#4A5266").cgColor); g.fillPath()
            g.addPath(path); g.setStrokeColor(SKColor(hex: "#7C8699").cgColor); g.setLineWidth(6); g.strokePath()
            g.setFillColor(SKColor.white.withAlphaComponent(0.12).cgColor)
            g.move(to: CGPoint(x: s.width * 0.2, y: s.height * 0.22)); g.addLine(to: CGPoint(x: s.width * 0.46, y: s.height * 0.06))
            g.addLine(to: CGPoint(x: s.width * 0.5, y: s.height * 0.3)); g.addLine(to: CGPoint(x: s.width * 0.28, y: s.height * 0.4)); g.closePath(); g.fillPath()
            g.setFillColor(SKColor.black.withAlphaComponent(0.25).cgColor)
            g.fillEllipse(in: CGRect(x: s.width * 0.55, y: s.height * 0.5, width: s.width * 0.18, height: s.height * 0.14))
            g.fillEllipse(in: CGRect(x: s.width * 0.3, y: s.height * 0.62, width: s.width * 0.12, height: s.height * 0.1))
        }
    }

    /// Debris slab: a low plate with a hazard stripe, hopped over.
    var low: SKTexture {
        make("low", size: CGSize(width: 300, height: 85)) { g, s in
            g.setFillColor(SKColor(hex: "#4A5266").cgColor); g.fill(CGRect(origin: .zero, size: s))
            g.setFillColor(SKColor(hex: "#2D3442").cgColor); g.fill(CGRect(x: 0, y: s.height * 0.6, width: s.width, height: s.height * 0.4))
            g.setFillColor(SKColor(hex: "#F97B2F").cgColor); g.fill(CGRect(x: 0, y: 0, width: s.width, height: s.height * 0.22))
            g.setFillColor(SKColor.black.withAlphaComponent(0.3).cgColor)
            var x: CGFloat = -20
            while x < s.width + 20 {
                g.move(to: CGPoint(x: x, y: 0)); g.addLine(to: CGPoint(x: x + 14, y: 0))
                g.addLine(to: CGPoint(x: x + 14 - 18, y: s.height * 0.22)); g.addLine(to: CGPoint(x: x - 18, y: s.height * 0.22)); g.closePath(); g.fillPath()
                x += 32
            }
        }
    }

    /// Laser gate: two pale posts carrying a flare beam, dived under.
    var beam: SKTexture {
        make("beam", size: CGSize(width: 300, height: 320)) { g, s in
            let bar: CGFloat = 90, post: CGFloat = 7
            g.setFillColor(SKColor(hex: "#C9CFDA").cgColor)
            g.fill(CGRect(x: 0, y: 0, width: post, height: s.height)); g.fill(CGRect(x: s.width - post, y: 0, width: post, height: s.height))
            g.setFillColor(SKColor(hex: "#F97B2F", alpha: 0.35).cgColor); g.fill(CGRect(x: 0, y: 0, width: s.width, height: bar))
            g.setFillColor(SKColor(hex: "#F97B2F").cgColor); g.fill(CGRect(x: 0, y: bar * 0.3, width: s.width, height: bar * 0.4))
            g.setFillColor(SKColor(hex: "#FFE1C2").cgColor); g.fill(CGRect(x: 0, y: bar * 0.44, width: s.width, height: bar * 0.12))
        }
    }

    /// Boss shot.
    var laser: SKTexture {
        make("laser", size: CGSize(width: 150, height: 360)) { g, s in
            let colors = [SKColor(hex: "#F97B2F", alpha: 0.15).cgColor, SKColor(hex: "#FFF3EC").cgColor, SKColor(hex: "#F97B2F", alpha: 0.15).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
                g.drawLinearGradient(grad, start: .zero, end: CGPoint(x: s.width, y: 0), options: [])
            }
            g.setFillColor(SKColor(hex: "#F97B2F", alpha: 0.5).cgColor)
            g.fill(CGRect(x: -s.width * 0.25, y: 0, width: s.width * 1.5, height: s.height * 0.1))
        }
    }

    var coin: SKTexture {
        make("coin", size: CGSize(width: 100, height: 100)) { g, s in
            let r: CGFloat = 46, cx = s.width / 2, cy = s.height / 2
            g.setFillColor(SKColor(hex: "#A9731B").cgColor); g.fillEllipse(in: CGRect(x: cx - r, y: cy - r + r * 0.16, width: r * 2, height: r * 2))
            g.setFillColor(SKColor(hex: "#F2B544").cgColor); g.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            g.setStrokeColor(SKColor(hex: "#A9731B").cgColor); g.setLineWidth(r * 0.14)
            g.strokeEllipse(in: CGRect(x: cx - r * 0.42, y: cy - r * 0.42, width: r * 0.84, height: r * 0.84))
        }
    }

    var gem: SKTexture {
        make("gem", size: CGSize(width: 100, height: 100)) { g, s in
            let r: CGFloat = 48, cx = s.width / 2, cy = s.height / 2
            let hex = CGMutablePath()
            hex.move(to: CGPoint(x: cx, y: cy - r))
            hex.addLine(to: CGPoint(x: cx + r * 0.85, y: cy - r * 0.5)); hex.addLine(to: CGPoint(x: cx + r * 0.85, y: cy + r * 0.5))
            hex.addLine(to: CGPoint(x: cx, y: cy + r)); hex.addLine(to: CGPoint(x: cx - r * 0.85, y: cy + r * 0.5)); hex.addLine(to: CGPoint(x: cx - r * 0.85, y: cy - r * 0.5))
            hex.closeSubpath()
            g.addPath(hex); g.setFillColor(SKColor(hex: "#7EDCF2").cgColor); g.fillPath()
            g.setStrokeColor(SKColor(hex: "#062028", alpha: 0.45).cgColor); g.setLineWidth(5)
            g.move(to: CGPoint(x: cx, y: cy - r)); g.addLine(to: CGPoint(x: cx, y: cy + r))
            g.move(to: CGPoint(x: cx - r * 0.85, y: cy - r * 0.5)); g.addLine(to: CGPoint(x: cx, y: cy)); g.addLine(to: CGPoint(x: cx + r * 0.85, y: cy - r * 0.5))
            g.strokePath()
            g.setFillColor(SKColor.white.withAlphaComponent(0.35).cgColor)
            g.move(to: CGPoint(x: cx, y: cy - r)); g.addLine(to: CGPoint(x: cx - r * 0.85, y: cy - r * 0.5)); g.addLine(to: CGPoint(x: cx, y: cy)); g.closePath(); g.fillPath()
        }
    }

    func orb(_ boost: BoostKind) -> SKTexture {
        let col = RGBA(hex: boost.colorHex)
        return make("orb.\(boost.rawValue)", size: CGSize(width: 100, height: 100)) { g, s in
            let r: CGFloat = 48, cx = s.width / 2, cy = s.height / 2
            let colors = [SKColor.white.cgColor, SKColor(col).cgColor, SKColor(col.shaded(-0.3)).cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.35, 1]) else { return }
            g.saveGState()
            g.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)); g.clip()
            g.drawRadialGradient(grad, startCenter: CGPoint(x: cx - r * 0.3, y: cy - r * 0.35), startRadius: r * 0.1,
                                 endCenter: CGPoint(x: cx, y: cy), endRadius: r, options: [.drawsAfterEndLocation])
            g.restoreGState()
        }
    }
}
