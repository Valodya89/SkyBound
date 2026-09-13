import SpriteKit
import StarlaneCore

/// Renders whatever `RunController.simulation` contains. Owns no game state of its own.
final class RunScene: SKScene {
    private let controller: RunController
    private let textures = TextureFactory()
    private let world = SKNode()
    private let backdrop: BackdropNode
    private let entityLayer = SKNode()
    private var entityNodes: [Int: EntityNode] = [:]
    private let boss: BossNode
    private let ghost = GhostNode()
    private let ship: ShipNode
    private let effects: EffectsLayer
    private let slowmoTint = SKSpriteNode(color: SKColor(hex: "#7EDCF2"), size: .zero)
    private let strobe = SKSpriteNode(color: SKColor(hex: "#EBF5FF"), size: .zero)
    private let flash = SKSpriteNode(color: SKColor(hex: "#F97B2F"), size: .zero)
    private let nearMissFrame = SKShapeNode()
    private var lastBiomeIndex = -1
    private var skinID = ""
    private var rng = SystemRandomSource()

    init(controller: RunController) {
        self.controller = controller
        backdrop = BackdropNode(textures: textures)
        boss = BossNode(textures: textures)
        ship = ShipNode(textures: textures)
        effects = EffectsLayer(textures: textures)
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = SKColor(hex: "#0B0E14")

        addChild(world)
        backdrop.zPosition = 0
        boss.zPosition = 100
        ghost.zPosition = 200
        entityLayer.zPosition = 300
        ship.zPosition = 2000
        effects.zPosition = 3000
        for n in [backdrop, boss, ghost, entityLayer, ship, effects] as [SKNode] { world.addChild(n) }

        for (i, n) in [slowmoTint, strobe, flash].enumerated() {
            n.anchorPoint = .zero
            n.alpha = 0
            n.zPosition = 4000 + CGFloat(i)
            addChild(n)
        }
        nearMissFrame.strokeColor = SKColor(hex: "#F2B544")
        nearMissFrame.lineWidth = 4
        nearMissFrame.fillColor = .clear
        nearMissFrame.alpha = 0
        nearMissFrame.zPosition = 4010
        addChild(nearMissFrame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        layout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layout()
    }

    /// Pushes the presented size into the controller. Only a scene that is actually on screen may do this:
    /// `SKScene.init(size:)` also triggers `didChangeSize`, and a scene that never gets presented must not
    /// overwrite the real viewport with its placeholder size.
    private func layout() {
        guard view != nil, size.width > 0, size.height > 0 else { return }
        controller.viewportChanged(size)
        let proj = controller.simulation.projector
        backdrop.layout(size: size, projector: proj)
        ship.layout(width: proj.width)
        for n in [slowmoTint, strobe, flash] { n.size = size }
        nearMissFrame.path = CGPath(rect: CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4), transform: nil)
        lastBiomeIndex = -1
    }

    private var lastUpdate: TimeInterval = 0

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 1 : min(max((currentTime - lastUpdate) * 60, 0), 3)
        lastUpdate = currentTime
        let events = controller.advance(now: currentTime)
        let sim = controller.simulation
        let proj = sim.projector
        let H = size.height

        if sim.biomeIndex != lastBiomeIndex {
            backdrop.apply(biome: sim.biome, animated: lastBiomeIndex >= 0 && controller.phase != .attract)
            lastBiomeIndex = sim.biomeIndex
        }
        backdrop.update(sim: sim, time: currentTime, dt: dt)

        // Entities
        var seen = Set<Int>()
        for e in sim.entities {
            seen.insert(e.id)
            let node: EntityNode
            if let existing = entityNodes[e.id] {
                node = existing
            } else {
                node = EntityNode(entity: e, textures: textures)
                entityLayer.addChild(node)
                entityNodes[e.id] = node
            }
            let p = proj.scale(atDepth: e.z)
            node.isHidden = p <= 0.02
            if !node.isHidden { node.update(e, proj: proj, biome: sim.biome, sceneHeight: H, hintDepth: sim.hintDepth) }
        }
        for (id, node) in entityNodes where !seen.contains(id) {
            node.removeFromParent()
            entityNodes[id] = nil
        }

        boss.update(boss: sim.boss, proj: proj, sceneHeight: H, time: currentTime)
        ghost.update(hint: controller.phase == .attract ? nil : sim.pathHint, proj: proj, sceneHeight: H)
        ship.update(sim: sim, sceneHeight: H, time: currentTime)

        slowmoTint.alpha = (sim.slowmoFrames > 0 && controller.phase == .playing) ? 0.10 : 0
        strobe.alpha = sim.strobe * 0.55
        flash.alpha = sim.flash * 0.45
        if sim.cameraShake > 0, controller.shakeEnabled {
            world.position = CGPoint(x: rng.next(in: -1...1) * 11 * sim.cameraShake, y: rng.next(in: -1...1) * 11 * sim.cameraShake)
        } else {
            world.position = .zero
        }

        for e in events { render(e, sim: sim) }
    }

    func applySkin(_ skin: Skin) {
        guard skin.id != skinID else { return }
        skinID = skin.id
        ship.apply(skin: skin)
    }

    private func render(_ event: RunEvent, sim: RunSimulation) {
        let proj = sim.projector
        let W = proj.width, H = size.height, HZ = proj.horizonY, PY = proj.playerY
        func at(lane: Int, z: Double, lift: Double) -> CGPoint {
            let p = proj.project(lane: lane, z: z)
            return CGPoint(x: p.x, y: H - (p.y - lift))
        }
        switch event {
        case .coinCollected(let lane, let z, let value):
            effects.burst(at: at(lane: lane, z: z, lift: 14), color: SKColor(hex: "#F2B544"), count: 7, speed: 2.4, size: 3)
            effects.floatText("+\(value)", at: at(lane: lane, z: z, lift: 42), color: SKColor(hex: "#F2B544"))
        case .gemCollected(let lane, let z):
            effects.burst(at: at(lane: lane, z: z, lift: 14), color: SKColor(hex: "#7EDCF2"), count: 14, speed: 3, size: 3.4)
            effects.floatText("+1 GEM", at: at(lane: lane, z: z, lift: 46), color: SKColor(hex: "#7EDCF2"))
        case .orbCollected(let lane, let z, let boost):
            let c = SKColor(hex: boost.colorHex)
            effects.ring(at: at(lane: lane, z: z, lift: 14), radius: W * 0.06, color: c)
            effects.burst(at: at(lane: lane, z: z, lift: 14), color: c, count: 18, speed: 3.4)
            effects.floatText(boost.name.uppercased(), at: at(lane: lane, z: z, lift: 48), color: c)
        case .nearMiss(let pts):
            effects.floatText("NEAR MISS +\(pts)", at: CGPoint(x: sim.ship.x, y: H - (PY - 70)), color: SKColor(hex: "#F2B544"))
            nearMissFrame.removeAllActions()
            nearMissFrame.alpha = 0.9
            nearMissFrame.run(.fadeOut(withDuration: 0.32))
        case .shieldBlocked:
            let p = CGPoint(x: sim.ship.x, y: H - PY)
            effects.ring(at: p, radius: W * 0.10, color: SKColor(hex: "#7EDCF2"))
            effects.burst(at: p, color: SKColor(hex: "#7EDCF2"), count: 22, speed: 4)
            effects.floatText("BLOCKED", at: CGPoint(x: p.x, y: p.y + 56), color: SKColor(hex: "#7EDCF2"))
        case .crashed:
            let p = CGPoint(x: sim.ship.x, y: H - (PY + sim.ship.yOffset))
            effects.burst(at: p, color: SKColor(hex: "#F97B2F"), count: 44, speed: 6, size: 4.5)
            effects.ring(at: p, radius: W * 0.08, color: SKColor(hex: "#F97B2F"))
        case .bossSpawned(let name):
            effects.floatText(name, at: CGPoint(x: W / 2, y: H - H * 0.42), color: SKColor(hex: "#F97B2F"), big: true)
        case .bossDefeated(let bonus):
            let p = CGPoint(x: W / 2, y: H - HZ)
            effects.burst(at: p, color: SKColor(hex: "#F97B2F"), count: 60, speed: 7, size: 5)
            effects.ring(at: p, radius: W * 0.1, color: SKColor(hex: "#F2B544"))
            effects.floatText("WARDEN DOWN +\(bonus)", at: CGPoint(x: W / 2, y: H - H * 0.4), color: SKColor(hex: "#F2B544"), big: true)
        default:
            break
        }
    }
}
