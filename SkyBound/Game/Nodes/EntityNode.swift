import SpriteKit
import SkyBoundCore

/// One track object: a fog-tinted sprite, a soft shadow and (for hurdles/beams) an input hint.
final class EntityNode: SKNode {
    let kind: EntityKind
    private let sprite = SKSpriteNode()
    private let shadow: SKSpriteNode
    private var hint: SKLabelNode?
    private var icon: SKSpriteNode?

    init(entity: Entity, textures: TextureFactory) {
        kind = entity.kind
        shadow = SKSpriteNode(texture: textures.softShadow)
        super.init()
        shadow.zPosition = -1
        switch entity.kind {
        case .wall:
            sprite.texture = textures.wall
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        case .low:
            sprite.texture = textures.low
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            hint = makeHint("▲", color: SKColor(hex: "#FFE1C2"))
        case .beam:
            sprite.texture = textures.beam
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            hint = makeHint("▼", color: SKColor(hex: "#7EDCF2"))
            shadow.isHidden = true
        case .laser:
            sprite.texture = textures.laser
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            shadow.isHidden = true
        case .coin:
            sprite.texture = textures.coin
        case .gem:
            sprite.texture = textures.gem
        case .orb:
            sprite.texture = textures.orb(entity.boost ?? .shield)
            let l = SKSpriteNode(texture: textures.symbol((entity.boost ?? .shield).symbol))
            l.zPosition = 1
            icon = l
            addChild(l)
        }
        addChild(shadow)
        addChild(sprite)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func makeHint(_ text: String, color: SKColor) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: SceneFont.heavy)
        l.text = text
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .center
        l.zPosition = 2
        addChild(l)
        return l
    }

    /// Obstacle width as a fraction of the viewport. A lane is 0.2667 of the width at the near plane,
    /// so 0.24 keeps blocks visibly inside their lane lines (the prototype used 0.30 and spilled over).
    static let obstacleWidthFraction = 0.24

    func update(_ e: Entity, proj: Projector, biome: Biome, sceneHeight: CGFloat, hintDepth: Double) {
        let W = proj.width
        let ow = W * Self.obstacleWidthFraction
        let p = proj.project(lane: e.lane, z: e.z)
        let s = p.scale
        let baseY = sceneHeight - p.y
        let fog = proj.fogAmount(atDepth: e.z)
        let shadowAlpha = min(max(1 - e.z / Projector.maxDepth, 0), 1)
        sprite.color = SKColor(biome.horizon)
        sprite.colorBlendFactor = fog
        zPosition = Projector.maxDepth - e.z
        // Objects that have passed the ship fly towards the camera and inflate; fade them out instead of
        // letting them sit huge at the bottom corners.
        alpha = e.z < 0 ? max(0, 1 + e.z / 55) : 1

        switch e.kind {
        case .wall:
            let w = ow * s, h = W * 0.22 * s
            sprite.size = CGSize(width: w, height: h * 1.18)
            sprite.position = CGPoint(x: p.x, y: baseY)
            place(shadow: CGPoint(x: p.x, y: baseY), radius: w * 0.52, alpha: shadowAlpha * 0.5)
        case .low:
            let w = ow * s, h = W * 0.085 * s
            sprite.size = CGSize(width: w, height: h)
            sprite.position = CGPoint(x: p.x, y: baseY)
            place(shadow: CGPoint(x: p.x, y: baseY), radius: w * 0.5, alpha: shadowAlpha * 0.45)
            updateHint(z: e.z, at: CGPoint(x: p.x, y: baseY + h + 7 * s), size: max(9, 15 * s), depth: hintDepth)
        case .beam:
            let w = ow * s, h = W * 0.32 * s, bar = W * 0.09 * s
            sprite.size = CGSize(width: w, height: h)
            sprite.position = CGPoint(x: p.x, y: baseY)
            updateHint(z: e.z, at: CGPoint(x: p.x, y: baseY + h - bar - 16 * s), size: max(9, 15 * s), depth: hintDepth)
        case .laser:
            sprite.size = CGSize(width: W * 0.15 * s, height: W * 0.36 * s)
            sprite.position = CGPoint(x: p.x, y: baseY)
            alpha = min(alpha, min(max(1.2 - e.z / Projector.maxDepth, 0), 1))
        case .coin:
            let r = W * 0.046 * s
            let sq = max(0.16, abs(cos(e.spin)))
            sprite.size = CGSize(width: 2 * r * sq, height: 2 * r)
            sprite.position = CGPoint(x: p.x, y: baseY + r * 1.9)
            place(shadow: CGPoint(x: p.x, y: baseY), radius: r * 0.75, alpha: shadowAlpha * 0.32)
        case .gem:
            let r = W * 0.05 * s
            sprite.size = CGSize(width: 2 * r, height: 2 * r)
            sprite.position = CGPoint(x: p.x, y: baseY + r * 2)
            sprite.zRotation = -sin(e.spin * 0.5) * 0.22
            place(shadow: CGPoint(x: p.x, y: baseY), radius: r * 0.7, alpha: shadowAlpha * 0.3)
        case .orb:
            let r = W * 0.052 * s
            sprite.size = CGSize(width: 2 * r, height: 2 * r)
            sprite.position = CGPoint(x: p.x, y: baseY + r * 2)
            icon?.position = sprite.position
            icon?.size = CGSize(width: r * 1.1, height: r * 1.1)
            place(shadow: CGPoint(x: p.x, y: baseY), radius: r * 0.8, alpha: shadowAlpha * 0.32)
        }
    }

    private func place(shadow at: CGPoint, radius: Double, alpha: Double) {
        shadow.position = at
        shadow.size = CGSize(width: radius * 2, height: radius * 0.6)
        shadow.alpha = alpha
    }

    private func updateHint(z: Double, at: CGPoint, size: Double, depth: Double) {
        guard let hint else { return }
        if z < depth {
            hint.isHidden = false
            hint.alpha = min(max((depth - z) / (depth * 0.6), 0), 1)
            hint.fontSize = size
            hint.position = at
        } else {
            hint.isHidden = true
        }
    }
}
