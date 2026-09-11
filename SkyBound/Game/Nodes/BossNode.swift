import SpriteKit
import SkyBoundCore

/// The sentinel hovering on the horizon. Cracks appear as it loses health.
final class BossNode: SKNode {
    private let hull = SKShapeNode()
    private let facet = SKShapeNode()
    private let eye: SKSpriteNode
    private let scars = SKNode()
    private let shadow: SKSpriteNode

    init(textures: TextureFactory) {
        eye = SKSpriteNode(texture: textures.radialGlow(key: "bossEye", color: RGBA(hex: "#F97B2F"), inner: 1))
        shadow = SKSpriteNode(texture: textures.softShadow)
        super.init()
        hull.lineWidth = 0
        hull.fillColor = SKColor(hex: "#1B2230")
        facet.lineWidth = 0
        facet.fillColor = SKColor(hex: "#2E3A4E")
        shadow.alpha = 0.22
        addChild(shadow)
        addChild(hull)
        addChild(facet)
        addChild(eye)
        addChild(scars)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(boss: BossState?, proj: Projector, sceneHeight: CGFloat, time: TimeInterval) {
        guard let boss else {
            isHidden = true
            return
        }
        isHidden = false
        let W = proj.width, H = proj.height, HZ = proj.horizonY
        let bob = sin(time * 1000 / 430) * W * 0.09
        let bx = W / 2 + bob
        let by = sceneHeight - (HZ - H * 0.055)

        let hp = CGMutablePath()
        hp.move(to: CGPoint(x: bx, y: by + W * 0.09))
        hp.addLine(to: CGPoint(x: bx + W * 0.18, y: by))
        hp.addLine(to: CGPoint(x: bx + W * 0.10, y: by - W * 0.065))
        hp.addLine(to: CGPoint(x: bx - W * 0.10, y: by - W * 0.065))
        hp.addLine(to: CGPoint(x: bx - W * 0.18, y: by))
        hp.closeSubpath()
        hull.path = hp
        let fp = CGMutablePath()
        fp.move(to: CGPoint(x: bx, y: by + W * 0.09))
        fp.addLine(to: CGPoint(x: bx + W * 0.18, y: by))
        fp.addLine(to: CGPoint(x: bx, y: by + W * 0.02))
        fp.closeSubpath()
        facet.path = fp

        let eyeR = W * 0.062 * (boss.isTelegraphing ? 1.3 : 1)
        eye.position = CGPoint(x: bx, y: by)
        eye.size = CGSize(width: eyeR * 2, height: eyeR * 2)

        shadow.position = CGPoint(x: bx, y: sceneHeight - (HZ + H * 0.03))
        shadow.size = CGSize(width: W * 0.32, height: W * 0.1)

        scars.removeAllChildren()
        scars.alpha = 1 - boss.healthFraction
        for i in 0..<4 {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: bx - W * 0.12 + Double(i) * W * 0.08, y: by + W * 0.05))
            p.addLine(to: CGPoint(x: bx - W * 0.09 + Double(i) * W * 0.08, y: by - W * 0.05))
            let l = SKShapeNode(path: p)
            l.strokeColor = SKColor(hex: "#7EDCF2")
            l.lineWidth = 1.6
            scars.addChild(l)
        }
    }
}

/// "Go here" marker: a dashed rocket outline in the safe lane, eased into place so it never snaps.
final class GhostNode: SKNode {
    private let outline = SKShapeNode()
    private let label = SKLabelNode(fontNamed: SceneFont.heavy)
    private var currentX: CGFloat = 0
    private var wasHidden = true
    private var pulse: Double = 0

    override init() {
        super.init()
        outline.strokeColor = SKColor(hex: "#7EDCF2")
        outline.lineWidth = 2.2
        outline.fillColor = SKColor(hex: "#7EDCF2", alpha: 0.10)
        outline.alpha = 0.85
        label.text = "SAFE"
        label.fontSize = 10
        label.fontColor = SKColor(hex: "#7EDCF2")
        label.alpha = 0.9
        label.horizontalAlignmentMode = .center
        addChild(outline)
        addChild(label)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(hint: PathHint?, proj: Projector, sceneHeight: CGFloat) {
        guard let hint else {
            isHidden = true
            wasHidden = true
            return
        }
        let p = proj.project(lane: hint.lane, z: min(max(hint.z, 20), Projector.maxDepth))
        guard p.scale > 0.05 else {
            isHidden = true
            wasHidden = true
            return
        }
        isHidden = false
        // Snap on first appearance, then ease so a lane switch glides instead of jumping.
        if wasHidden { currentX = p.x; wasHidden = false } else { currentX += (p.x - currentX) * 0.22 }
        pulse += 0.09
        let r = proj.width * 0.062 * p.scale
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: r * 1.45))
        path.addQuadCurve(to: CGPoint(x: r * 0.62, y: -r * 0.75), control: CGPoint(x: r * 0.78, y: r * 0.45))
        path.addLine(to: CGPoint(x: r * 1.08, y: -r * 0.95))
        path.addLine(to: CGPoint(x: -r * 1.08, y: -r * 0.95))
        path.addLine(to: CGPoint(x: -r * 0.62, y: -r * 0.75))
        path.addQuadCurve(to: CGPoint(x: 0, y: r * 1.45), control: CGPoint(x: -r * 0.78, y: r * 0.45))
        path.closeSubpath()
        outline.path = path.copy(dashingWithPhase: 0, lengths: [5, 4])
        outline.position = CGPoint(x: currentX, y: sceneHeight - (p.y - r * 0.5))
        outline.alpha = 0.7 + 0.25 * sin(pulse)
        zPosition = Projector.maxDepth - hint.z
        label.fontSize = max(8, 12 * p.scale + 4)
        label.position = CGPoint(x: currentX, y: sceneHeight - (p.y - r * 2))
    }
}
