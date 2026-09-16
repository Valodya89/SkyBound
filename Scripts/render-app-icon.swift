// Renders the Starlane app icon (1024×1024) with CoreGraphics.
// Usage: swift Scripts/render-app-icon.swift Starlane/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
// Then regenerate the tinted variant: python3 -c "from PIL import Image, ImageOps; ImageOps.autocontrast(Image.open(\"…/AppIcon-1024.png\").convert(\"L\"), cutoff=1).save(\"…/AppIcon-1024-tinted.png\")"
import AppKit
import CoreGraphics

// Starlane app icon — 1024×1024, rendered with CoreGraphics.
// Deep-space ground, launch-corridor light cone, the flare rocket climbing, ice star field.
let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setShouldAntialias(true)
ctx.setAllowsAntialiasing(true)
ctx.interpolationQuality = .high

func c(_ hex: String, _ a: CGFloat = 1) -> CGColor {
    var h = hex; if h.hasPrefix("#") { h.removeFirst() }
    let v = UInt32(h, radix: 16)!
    return CGColor(colorSpace: cs, components: [CGFloat((v >> 16) & 0xff) / 255, CGFloat((v >> 8) & 0xff) / 255, CGFloat(v & 0xff) / 255, a])!
}
// Coordinates below are in a top-left origin; flip once.
ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)

func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
func linear(_ colors: [CGColor], _ locs: [CGFloat], from: CGPoint, to: CGPoint, options: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!
    ctx.drawLinearGradient(g, start: from, end: to, options: options)
}
func radial(_ colors: [CGColor], _ locs: [CGFloat], center: CGPoint, r: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: r, options: [])
}

// 1. Ground: near-black navy with a slow lift toward the top.
ctx.setFillColor(c("#0B0E14")); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
linear([c("#141B2B"), c("#0B0E14")], [0, 1], from: P(512, 0), to: P(512, 1024))

// 2. Nebula washes — very restrained, ice on the upper right, flare warmth low.
ctx.saveGState()
ctx.setBlendMode(.screen)
radial([c("#7EDCF2", 0.16), c("#7EDCF2", 0)], [0, 1], center: P(760, 220), r: 520)
radial([c("#F97B2F", 0.22), c("#F97B2F", 0)], [0, 1], center: P(512, 830), r: 420)
ctx.restoreGState()

// 3. Star field — deterministic pseudo-random, a few brighter ice stars.
var seed: UInt64 = 0x5EED_5B0D
func rnd() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat((seed >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
}
for i in 0..<170 {
    let x = rnd() * S, y = rnd() * S
    // keep the corridor and rocket area calmer
    let dx = abs(x - 512)
    if y > 420 && dx < 200 { continue }
    let big = i % 23 == 0
    let r: CGFloat = big ? 3.2 + rnd() * 2.2 : 0.9 + rnd() * 1.8
    let a: CGFloat = big ? 0.9 : 0.25 + rnd() * 0.5
    ctx.setFillColor(big ? c("#7EDCF2", a) : c("#EEF1F5", a))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    if big {
        ctx.setStrokeColor(c("#7EDCF2", 0.55)); ctx.setLineWidth(1.6)
        let l = r * 4
        ctx.move(to: P(x - l, y)); ctx.addLine(to: P(x + l, y))
        ctx.move(to: P(x, y - l)); ctx.addLine(to: P(x, y + l))
        ctx.strokePath()
    }
}

// 3b. Planet horizon at the base: dark disc with an ice rim light and a warm launch glow.
let planetC = P(512, 1600), planetR: CGFloat = 780   // top of the disc at y = 820
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: planetC.x - planetR, y: planetC.y - planetR, width: 2 * planetR, height: 2 * planetR)); ctx.clip()
linear([c("#1B2436"), c("#0B0E14")], [0, 1], from: P(512, 820), to: P(512, 1024))
ctx.restoreGState()
ctx.saveGState(); ctx.setBlendMode(.screen)
ctx.addEllipse(in: CGRect(x: planetC.x - planetR, y: planetC.y - planetR, width: 2 * planetR, height: 2 * planetR)); ctx.clip()
linear([c("#7EDCF2", 0.55), c("#7EDCF2", 0)], [0, 1], from: P(512, 820), to: P(512, 880))
ctx.restoreGState()
ctx.setStrokeColor(c("#7EDCF2", 0.9)); ctx.setLineWidth(5)
ctx.addEllipse(in: CGRect(x: planetC.x - planetR, y: planetC.y - planetR, width: 2 * planetR, height: 2 * planetR)); ctx.strokePath()
// atmosphere haze above the horizon
ctx.saveGState(); ctx.setBlendMode(.screen)
let haze = CGGradient(colorsSpace: cs, colors: [c("#7EDCF2", 0.16), c("#7EDCF2", 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(haze, startCenter: planetC, startRadius: planetR, endCenter: planetC, endRadius: planetR + 200, options: [])
ctx.restoreGState()

// 4. Launch corridor: a light cone opening upward from the base, with faint lane ticks.
ctx.saveGState()
ctx.setBlendMode(.screen)
let cone = CGMutablePath()
cone.move(to: P(402, 826)); cone.addLine(to: P(622, 826)); cone.addLine(to: P(548, 150)); cone.addLine(to: P(476, 150)); cone.closeSubpath()
ctx.addPath(cone); ctx.clip()
linear([c("#F97B2F", 0.34), c("#F97B2F", 0.05), c("#F97B2F", 0)], [0, 0.55, 1], from: P(512, 826), to: P(512, 150))
ctx.restoreGState()
// corridor edge rules
ctx.saveGState()
ctx.setStrokeColor(c("#7EDCF2", 0.22)); ctx.setLineWidth(3)
ctx.setLineDash(phase: 0, lengths: [22, 26])
ctx.move(to: P(410, 822)); ctx.addLine(to: P(482, 180)); ctx.strokePath()
ctx.move(to: P(614, 822)); ctx.addLine(to: P(542, 180)); ctx.strokePath()
ctx.restoreGState()

// 5. Tick rulers on the left and right edges (design-system motif).
ctx.setStrokeColor(c("#7EDCF2", 0.28)); ctx.setLineWidth(3)
for i in 0..<13 {
    let y: CGFloat = 214 + CGFloat(i) * 44
    let len: CGFloat = i % 5 == 0 ? 34 : 16
    ctx.move(to: P(120, y)); ctx.addLine(to: P(120 + len, y))
    ctx.move(to: P(904, y)); ctx.addLine(to: P(904 - len, y))
}
ctx.strokePath()

// 6. Corner brackets.
ctx.setStrokeColor(c("#F97B2F", 0.85)); ctx.setLineWidth(9); ctx.setLineCap(.square)
let m: CGFloat = 132, L: CGFloat = 64
for (sx, sy) in [(1, 1), (-1, 1), (1, -1), (-1, -1)] as [(CGFloat, CGFloat)] {
    let ox = sx > 0 ? m : S - m, oy = sy > 0 ? m : S - m
    ctx.move(to: P(ox, oy + sy * L)); ctx.addLine(to: P(ox, oy)); ctx.addLine(to: P(ox + sx * L, oy))
}
ctx.strokePath()

// 7. Rocket — same silhouette as the in-app RocketMark, scaled onto a 120-unit grid.
let k: CGFloat = 6.0              // 120 units → 648 px
let ox: CGFloat = 512 - 60 * k, oy: CGFloat = 512 - 64 * k
func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { P(ox + x * k, oy + y * k) }

// exhaust glow behind everything
ctx.saveGState(); ctx.setBlendMode(.screen)
radial([c("#F97B2F", 0.6), c("#F97B2F", 0.18), c("#F97B2F", 0)], [0, 0.45, 1], center: pt(60, 100), r: 170)
ctx.restoreGState()

// flame
let flame = CGMutablePath()
flame.move(to: pt(48, 84)); flame.addQuadCurve(to: pt(60, 122), control: pt(54, 104)); flame.addQuadCurve(to: pt(72, 84), control: pt(66, 104)); flame.closeSubpath()
ctx.addPath(flame); ctx.setFillColor(c("#F97B2F")); ctx.fillPath()
let core = CGMutablePath()
core.move(to: pt(54, 84)); core.addQuadCurve(to: pt(60, 106), control: pt(57, 96)); core.addQuadCurve(to: pt(66, 84), control: pt(63, 96)); core.closeSubpath()
ctx.addPath(core); ctx.setFillColor(c("#FFE1C2")); ctx.fillPath()

// fins (darker, behind hull)
let fins = CGMutablePath()
fins.move(to: pt(46, 58)); fins.addLine(to: pt(24, 96)); fins.addLine(to: pt(46, 86)); fins.closeSubpath()
fins.move(to: pt(74, 58)); fins.addLine(to: pt(96, 96)); fins.addLine(to: pt(74, 86)); fins.closeSubpath()
ctx.addPath(fins); ctx.setFillColor(c("#B8C0CE")); ctx.fillPath()
ctx.addPath(fins); ctx.setStrokeColor(c("#0B0E14", 0.25)); ctx.setLineWidth(3); ctx.strokePath()

// hull with a soft vertical shade
let hull = CGMutablePath()
hull.move(to: pt(60, 2))
hull.addCurve(to: pt(76, 82), control1: pt(77, 22), control2: pt(82, 48))
hull.addLine(to: pt(44, 82))
hull.addCurve(to: pt(60, 2), control1: pt(38, 48), control2: pt(43, 22))
hull.closeSubpath()
ctx.saveGState(); ctx.addPath(hull); ctx.clip()
linear([c("#FFFFFF"), c("#E9EDF3"), c("#C5CCD8")], [0, 0.55, 1], from: pt(44, 40), to: pt(76, 40))
ctx.restoreGState()
// hull shadow band on the right
ctx.saveGState(); ctx.addPath(hull); ctx.clip()
linear([c("#0B0E14", 0), c("#0B0E14", 0.22)], [0.6, 1], from: pt(44, 40), to: pt(76, 40))
ctx.restoreGState()

ctx.addPath(hull); ctx.setStrokeColor(c("#0B0E14", 0.35)); ctx.setLineWidth(3); ctx.strokePath()

// porthole and stripe in flare, porthole with an ice inner glass
ctx.setFillColor(c("#F97B2F")); ctx.fillEllipse(in: CGRect(x: pt(51, 33).x, y: pt(51, 33).y, width: 18 * k, height: 18 * k))
ctx.setFillColor(c("#062028")); ctx.fillEllipse(in: CGRect(x: pt(54, 36).x, y: pt(54, 36).y, width: 12 * k, height: 12 * k))
ctx.setFillColor(c("#7EDCF2")); ctx.fillEllipse(in: CGRect(x: pt(55.5, 37.5).x, y: pt(55.5, 37.5).y, width: 9 * k, height: 9 * k))
ctx.setFillColor(c("#FFFFFF", 0.85)); ctx.fillEllipse(in: CGRect(x: pt(56.5, 38.5).x, y: pt(56.5, 38.5).y, width: 3.2 * k, height: 3.2 * k))
ctx.saveGState(); ctx.addPath(hull); ctx.clip()
ctx.setFillColor(c("#F97B2F")); ctx.fill(CGRect(x: pt(40, 68).x, y: pt(40, 68).y, width: 40 * k, height: 6 * k))
ctx.restoreGState()


let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote", out.path)
