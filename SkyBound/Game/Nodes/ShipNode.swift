import SpriteKit
import SkyBoundCore

/// The player's rocket: hull, fins, porthole, stripe, exhaust, shield/magnet rings and an exhaust trail.
final class ShipNode: SKNode {
    private let body = SKNode()
    private let fins = SKShapeNode()
    private let hull = SKShapeNode()
    private let shade = SKShapeNode()
    private let porthole = SKShapeNode()
    private let stripe = SKShapeNode()
    private let flame = SKShapeNode()
    private let flameCore = SKShapeNode()
    private let shieldRing = SKShapeNode()
    private let magnetRing = SKShapeNode()
    private let shadow: SKSpriteNode
    private var trail: [SKSpriteNode] = []
    private var r: Double = 25
    /// Empty until the first `apply(skin:)`, so the first call always sets the fills (a shape node's default
    /// fill is clear).
    private var colorHex = ""
    private var rng = SystemRandomSource()

    init(textures: TextureFactory) {
        shadow = SKSpriteNode(texture: textures.softShadow)
        super.init()
        shadow.zPosition = -2
        addChild(shadow)
        for _ in 0..<9 {
            let t = SKSpriteNode(texture: textures.dot)
            t.colorBlendFactor = 1
            t.zPosition = -1
            addChild(t)
            trail.append(t)
        }
        for n in [flame, flameCore, fins, hull, shade, stripe, porthole, shieldRing, magnetRing] {
            n.lineWidth = 0
            body.addChild(n)
        }
        shieldRing.lineWidth = 2.6
        shieldRing.strokeColor = SKColor(hex: "#7EDCF2", alpha: 0.9)
        shieldRing.fillColor = SKColor(hex: "#7EDCF2", alpha: 0.12)
        magnetRing.lineWidth = 1.8
        magnetRing.strokeColor = SKColor(hex: "#B48CFF", alpha: 0.6)
        magnetRing.fillColor = .clear
        porthole.fillColor = SKColor(hex: "#F97B2F")
        stripe.fillColor = SKColor(hex: "#F97B2F")
        shade.fillColor = SKColor.black.withAlphaComponent(0.16)
        flame.fillColor = SKColor(hex: "#F97B2F")
        flameCore.fillColor = SKColor(hex: "#FFE1C2")
        addChild(body)
        apply(skin: SkinCatalog.skin(SkinCatalog.defaultSkinID))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func layout(width: Double) {
        r = width * 0.064
        let h = CGMutablePath()
        h.move(to: pt(0, 1.45))
        h.addQuadCurve(to: pt(0.62, -0.75), control: pt(0.78, 0.45))
        h.addLine(to: pt(-0.62, -0.75))
        h.addQuadCurve(to: pt(0, 1.45), control: pt(-0.78, 0.45))
        h.closeSubpath()
        hull.path = h
        let sh = CGMutablePath()
        sh.move(to: pt(0, 1.45))
        sh.addQuadCurve(to: pt(-0.62, -0.75), control: pt(-0.78, 0.45))
        sh.addLine(to: pt(-0.1, -0.75))
        sh.addQuadCurve(to: pt(0, 1.45), control: pt(-0.2, 0.45))
        sh.closeSubpath()
        shade.path = sh
        let f = CGMutablePath()
        f.move(to: pt(0.5, -0.1)); f.addLine(to: pt(1.08, -0.95)); f.addLine(to: pt(0.5, -0.72)); f.closeSubpath()
        f.move(to: pt(-0.5, -0.1)); f.addLine(to: pt(-1.08, -0.95)); f.addLine(to: pt(-0.5, -0.72)); f.closeSubpath()
        fins.path = f
        porthole.path = CGPath(ellipseIn: CGRect(x: -r * 0.2, y: r * 0.3, width: r * 0.4, height: r * 0.4), transform: nil)
        stripe.path = CGPath(rect: CGRect(x: -r * 0.56, y: -r * 0.36, width: r * 1.12, height: r * 0.14), transform: nil)
        flame.path = poly([(-0.3, -0.7), (0, -1.75), (0.3, -0.7)])
        flameCore.path = poly([(-0.13, -0.7), (0, -1.25), (0.13, -0.7)])
        shieldRing.path = CGPath(ellipseIn: CGRect(x: -r * 1.8, y: -r * 1.8, width: r * 3.6, height: r * 3.6), transform: nil)
        let ring = CGPath(ellipseIn: CGRect(x: -r * 2.3, y: -r * 2.3, width: r * 4.6, height: r * 4.6), transform: nil)
        magnetRing.path = ring.copy(dashingWithPhase: 0, lengths: [4, 5])
    }

    private func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * r, y: y * r) }

    private func poly(_ pts: [(Double, Double)]) -> CGPath {
        let p = CGMutablePath()
        for (i, v) in pts.enumerated() {
            if i == 0 { p.move(to: pt(v.0, v.1)) } else { p.addLine(to: pt(v.0, v.1)) }
        }
        p.closeSubpath()
        return p
    }

    func apply(skin: Skin) {
        guard skin.colorHex != colorHex else { return }
        colorHex = skin.colorHex
        let c = RGBA(hex: skin.colorHex)
        hull.fillColor = SKColor(c)
        fins.fillColor = SKColor(c.shaded(-0.28))
        for t in trail { t.color = SKColor(hex: "#F97B2F") }
    }

    func update(sim: RunSimulation, sceneHeight: CGFloat, time: TimeInterval) {
        let ship = sim.ship
        let PY = sim.projector.playerY
        let py = sceneHeight - (PY + ship.yOffset)
        body.position = CGPoint(x: ship.x, y: py)
        body.zRotation = -ship.tilt
        body.yScale = ship.isDucking ? 0.58 : 1

        let fl = (0.75 + rng.nextUnit() * 0.25) * (ship.isAirborne ? 1.6 : 1)
        flame.yScale = fl
        flameCore.yScale = fl

        shieldRing.isHidden = !sim.hasShield
        magnetRing.isHidden = sim.magnetFrames <= 0
        if !magnetRing.isHidden {
            magnetRing.setScale(1 + sin(time * 1000 / 190) * 0.087)
        }

        let n = Double(trail.count)
        for (i, t) in trail.enumerated() {
            if i < ship.trail.count {
                let tr = ship.trail[i]
                let k = Double(i) / n
                t.isHidden = false
                t.position = CGPoint(x: tr.x, y: sceneHeight - (PY + tr.y + r * 0.9 + Double(i) * 3))
                t.size = CGSize(width: r * 0.5 * (1 - k), height: r * 0.3)
                t.alpha = (1 - k) * 0.35
            } else {
                t.isHidden = true
            }
        }

        let sh = min(max(1 + ship.yOffset / 130, 0.42), 1)
        shadow.position = CGPoint(x: ship.x, y: sceneHeight - (PY + r * 0.9))
        shadow.size = CGSize(width: r * 1.6 * sh, height: r * 0.5 * sh)
        shadow.alpha = min(max(0.42 + ship.yOffset / 110, 0.08), 0.42)
    }
}
