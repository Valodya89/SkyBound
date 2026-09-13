import SpriteKit
import StarlaneCore

/// Deep space: gradient, two nebula fields, stars, a ringed planet, the dark lower plane and the launch corridor.
final class BackdropNode: SKNode {
    private let textures: TextureFactory
    private var size = CGSize(width: 390, height: 844)
    private var proj = Projector(width: 390, height: 844)
    private var biome = BiomeCatalog.all[0]

    private let space = SKSpriteNode()
    private let spaceFade = SKSpriteNode()
    private let nebulaA = SKShapeNode()
    private let nebulaB = SKShapeNode()
    private var nebulaBaseX: [Double] = [0, 0]
    private let starLayer = SKNode()
    private var stars: [(node: SKSpriteNode, twinkle: Double, alpha: Double, x: Double)] = []
    private let planetGroup = SKNode()
    private let ringBack = SKShapeNode()
    private let ringFront = SKShapeNode()
    private let planet = SKShapeNode()
    private let planetBand = SKShapeNode()
    private let planetShade = SKShapeNode()
    private var planetBaseX: Double = 0
    private let ground = SKSpriteNode()
    private let groundFade = SKSpriteNode()
    private let road = SKShapeNode()
    private var laneTints: [SKShapeNode] = []
    private var dashes: [SKSpriteNode] = []
    private var edges: [SKSpriteNode] = []
    private var gates: [SKSpriteNode] = []
    private let horizonLine: SKSpriteNode
    private let auroraLayer = SKNode()
    private var auroras: [SKShapeNode] = []
    private let dustLayer = SKNode()
    private var dustBands: [SKShapeNode] = []
    private let telegraph = SKShapeNode()
    private var telegraphLane = -1

    private var rng = SystemRandomSource()
    private static let gateSpacing = 260.0

    init(textures: TextureFactory) {
        self.textures = textures
        horizonLine = SKSpriteNode(texture: textures.pixel)
        super.init()
        for (i, n) in [space, spaceFade, nebulaA, nebulaB, starLayer, planetGroup, ground, groundFade, road,
                       horizonLine, auroraLayer, dustLayer, telegraph].enumerated() {
            n.zPosition = CGFloat(i)
            addChild(n)
        }
        space.anchorPoint = .zero
        spaceFade.anchorPoint = .zero
        spaceFade.alpha = 0
        ground.anchorPoint = .zero
        groundFade.anchorPoint = .zero
        groundFade.alpha = 0
        for n in [nebulaA, nebulaB, planet, planetBand, planetShade, road, telegraph] { n.lineWidth = 0 }
        ringBack.lineWidth = 5
        ringBack.fillColor = .clear
        ringFront.lineWidth = 5
        ringFront.fillColor = .clear
        planetShade.fillColor = SKColor.black.withAlphaComponent(0.35)
        for n in [ringBack, planet, planetBand, planetShade, ringFront] { planetGroup.addChild(n) }
        planetGroup.zRotation = 0.28
        horizonLine.colorBlendFactor = 1
        telegraph.fillColor = SKColor(hex: "#F97B2F")
        telegraph.isHidden = true
        for _ in 0..<2 {
            let t = SKShapeNode()
            t.lineWidth = 0
            t.zPosition = road.zPosition + 0.1
            addChild(t)
            laneTints.append(t)
            let e = SKSpriteNode(texture: textures.edgeFade)
            e.colorBlendFactor = 1
            e.zPosition = road.zPosition + 0.3
            addChild(e)
            edges.append(e)
        }
        for _ in 0..<30 {
            let d = SKSpriteNode(texture: textures.pixel)
            d.colorBlendFactor = 1
            d.zPosition = road.zPosition + 0.2
            addChild(d)
            dashes.append(d)
        }
        for _ in 0..<7 {
            let g = SKSpriteNode(texture: textures.pixel)
            g.colorBlendFactor = 1
            g.zPosition = road.zPosition + 0.15
            addChild(g)
            gates.append(g)
        }
        for i in 0..<3 {
            let a = SKShapeNode()
            a.lineWidth = 0
            a.fillColor = SKColor(hex: "#5FFFD0")
            a.fillTexture = textures.verticalGradient(key: "aurora", stops: [
                (RGBA(hex: "#5FFFD0", alpha: 0), 0), (RGBA(hex: "#5FFFD0"), 0.5), (RGBA(hex: "#5FFFD0", alpha: 0), 1),
            ])
            a.zPosition = CGFloat(i)
            auroraLayer.addChild(a)
            auroras.append(a)
            let f = SKShapeNode()
            f.lineWidth = 0
            f.fillColor = .white
            f.alpha = 0.07
            dustLayer.addChild(f)
            dustBands.append(f)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func skY(_ topBasedY: Double) -> CGFloat { size.height - topBasedY }

    // MARK: Layout

    func layout(size: CGSize, projector: Projector) {
        self.size = size
        proj = projector
        let W = size.width, H = size.height, HZ = proj.horizonY

        space.position = CGPoint(x: -30, y: -30)
        space.size = CGSize(width: W + 60, height: H + 60)
        spaceFade.position = space.position
        spaceFade.size = space.size
        ground.position = CGPoint(x: -30, y: -30)
        ground.size = CGSize(width: W + 60, height: H - HZ + 30 + HZ * 0.12)
        groundFade.position = ground.position
        groundFade.size = ground.size

        nebulaA.path = CGPath(ellipseIn: CGRect(x: -W * 0.55, y: -HZ * 0.28, width: W * 1.1, height: HZ * 0.56), transform: nil)
        nebulaB.path = CGPath(ellipseIn: CGRect(x: -W * 0.5, y: -HZ * 0.22, width: W, height: HZ * 0.44), transform: nil)
        nebulaBaseX = [W * 0.25, W * 0.85]
        nebulaA.position = CGPoint(x: nebulaBaseX[0], y: skY(HZ * 0.35))
        nebulaB.position = CGPoint(x: nebulaBaseX[1], y: skY(HZ * 0.85))

        starLayer.removeAllChildren()
        stars = (0..<140).map { _ in
            let n = SKSpriteNode(texture: textures.dot)
            let s = rng.next(in: 0.7...2.2)
            n.size = CGSize(width: s, height: s)
            let x = rng.next(in: 0...W)
            n.position = CGPoint(x: x, y: skY(rng.next(in: 0...H)))
            starLayer.addChild(n)
            return (n, rng.next(in: 0.4...1.8), rng.next(in: 0.3...1), x)
        }

        let r = min(HZ * 0.17, W * 0.15)
        planetBaseX = W * 0.8
        planetGroup.position = CGPoint(x: planetBaseX, y: skY(HZ * 0.66))
        planet.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        planetBand.path = CGPath(ellipseIn: CGRect(x: -r * 0.98, y: -r * 0.12, width: r * 1.96, height: r * 0.2), transform: nil)
        let shade = CGMutablePath()
        shade.addArc(center: .zero, radius: r, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
        shade.closeSubpath()
        planetShade.path = shade
        let rx = r * 1.85, ry = r * 0.42
        ringBack.path = CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry), transform: nil)
        let front = CGMutablePath()
        var t = Double.pi
        front.move(to: CGPoint(x: -rx, y: 0))
        while t <= 2 * .pi + 0.001 {
            front.addLine(to: CGPoint(x: rx * cos(t), y: ry * sin(t)))
            t += 0.08
        }
        ringFront.path = front

        let roadHalf = W * 0.40
        let nL = proj.project(x: W / 2 - roadHalf, z: -Projector.cameraDistance * 0.55)
        let nR = proj.project(x: W / 2 + roadHalf, z: -Projector.cameraDistance * 0.55)
        let rp = CGMutablePath()
        rp.move(to: CGPoint(x: W / 2, y: skY(HZ)))
        rp.addLine(to: CGPoint(x: nL.x, y: skY(nL.y)))
        rp.addLine(to: CGPoint(x: nR.x, y: skY(nR.y)))
        rp.closeSubpath()
        road.path = rp

        let tintSpecs: [(Double, Double)] = [(-roadHalf, roadHalf - W * 0.1333), (W * 0.1333, W * 0.2667)]
        for (i, spec) in tintSpecs.enumerated() {
            let f0 = proj.project(x: W / 2 + spec.0, z: Projector.maxDepth * 0.9)
            let f1 = proj.project(x: W / 2 + spec.0 + spec.1, z: Projector.maxDepth * 0.9)
            let n0 = proj.project(x: W / 2 + spec.0, z: -Projector.cameraDistance * 0.55)
            let n1 = proj.project(x: W / 2 + spec.0 + spec.1, z: -Projector.cameraDistance * 0.55)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: f0.x, y: skY(f0.y)))
            p.addLine(to: CGPoint(x: f1.x, y: skY(f1.y)))
            p.addLine(to: CGPoint(x: n1.x, y: skY(n1.y)))
            p.addLine(to: CGPoint(x: n0.x, y: skY(n0.y)))
            p.closeSubpath()
            laneTints[i].path = p
            laneTints[i].alpha = 0.5
        }

        for (i, gx) in [-roadHalf, roadHalf].enumerated() {
            let far = proj.project(x: W / 2 + gx, z: Projector.maxDepth)
            let near = proj.project(x: W / 2 + gx, z: -Projector.cameraDistance * 0.55)
            let a = CGPoint(x: far.x, y: skY(far.y)), b = CGPoint(x: near.x, y: skY(near.y))
            let len = hypot(b.x - a.x, b.y - a.y)
            edges[i].size = CGSize(width: 2.5, height: len)
            edges[i].position = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            edges[i].zRotation = atan2(b.y - a.y, b.x - a.x) - .pi / 2
        }

        horizonLine.position = CGPoint(x: W / 2, y: skY(HZ))
        horizonLine.size = CGSize(width: W + 60, height: 2)

        for (i, f) in dustBands.enumerated() {
            f.path = CGPath(ellipseIn: CGRect(x: -W * 0.9, y: -14, width: W * 1.8, height: 28), transform: nil)
            f.position = CGPoint(x: W / 2, y: skY(HZ + 40 + Double(i) * 90))
        }
        apply(biome: biome, animated: false)
    }

    // MARK: Biome

    func apply(biome next: Biome, animated: Bool) {
        let previous = biome
        biome = next
        let spaceTex = textures.verticalGradient(key: "space.\(next.id)", stops: [(next.skyBottom, 0), (next.skyMid, 0.45), (next.skyTop, 1)])
        let groundTex = textures.verticalGradient(key: "ground.\(next.id)", stops: [
            (next.groundTop.withAlpha(0), 0), (next.groundTop.withAlpha(0.45), 0.3), (next.groundBottom.withAlpha(0.9), 1),
        ])
        if animated, previous.id != next.id {
            spaceFade.texture = spaceTex
            groundFade.texture = groundTex
            spaceFade.alpha = 0
            groundFade.alpha = 0
            let fade = SKAction.fadeIn(withDuration: 1.4)
            spaceFade.run(fade) { [weak self] in
                self?.space.texture = spaceTex
                self?.spaceFade.alpha = 0
            }
            groundFade.run(fade) { [weak self] in
                self?.ground.texture = groundTex
                self?.groundFade.alpha = 0
            }
        } else {
            space.texture = spaceTex
            ground.texture = groundTex
        }
        nebulaA.fillColor = SKColor(next.cloud.withAlpha(1))
        nebulaA.alpha = next.cloud.a
        nebulaB.fillColor = SKColor(next.hillFar)
        nebulaB.alpha = 0.5
        planet.fillColor = SKColor(next.hillNear)
        planetBand.fillColor = SKColor(next.hillNear.shaded(0.28))
        planetBand.alpha = 0.6
        let ring = SKColor(next.hillNear.shaded(0.42))
        ringBack.strokeColor = ring
        ringFront.strokeColor = ring
        road.fillTexture = textures.verticalGradient(key: "road.\(next.id)", stops: [
            (next.road.shaded(-0.25), 0), (next.road, 0.6), (next.road.mixed(with: next.horizon, 0.45), 1),
        ])
        road.fillColor = .white
        for t in laneTints { t.fillColor = SKColor(next.laneTint) }
        for d in dashes { d.color = SKColor(next.dash) }
        for e in edges { e.color = SKColor(next.edge) }
        for g in gates { g.color = SKColor(next.laneTint.mixed(with: next.edge, 0.45)) }
        horizonLine.isHidden = true
        auroraLayer.isHidden = next.hazard != .fog
        dustLayer.isHidden = next.hazard != .fog && next.hazard != .storm
    }

    // MARK: Per-frame

    func update(sim: RunSimulation, time: TimeInterval, dt: Double) {
        let W = size.width, H = size.height, HZ = proj.horizonY
        let camX = sim.cameraX

        for s in stars {
            s.node.alpha = s.alpha * (0.5 + 0.5 * sin(time * s.twinkle + s.x))
            s.node.position.x = s.x - camX * 0.03
        }
        nebulaA.position.x = nebulaBaseX[0] - camX * 0.02 + sin(time * 0.05) * 6
        nebulaB.position.x = nebulaBaseX[1] - camX * 0.025 - sin(time * 0.04) * 6
        planetGroup.position.x = planetBaseX - camX * 0.02

        // Scrolling lane dashes.
        let dashLen = 64.0, gap = 64.0, cyc = dashLen + gap
        let ph = sim.worldZ.truncatingRemainder(dividingBy: cyc)
        var di = 0
        for gx in [-W * 0.1333, W * 0.1333] {
            for i in 0..<15 {
                let d = dashes[di]
                di += 1
                let z0 = Double(i) * cyc - ph, z1 = z0 + dashLen
                if z1 < -Projector.cameraDistance * 0.5 {
                    d.isHidden = true
                    continue
                }
                d.isHidden = false
                let a0 = proj.project(x: W / 2 + gx, z: max(z0, -Projector.cameraDistance * 0.5))
                let a1 = proj.project(x: W / 2 + gx, z: max(z1, -Projector.cameraDistance * 0.5))
                let p0 = CGPoint(x: a0.x, y: skY(a0.y)), p1 = CGPoint(x: a1.x, y: skY(a1.y))
                let w = max(0.6, 3.2 * (a0.scale + a1.scale) / 2)
                d.size = CGSize(width: w, height: max(1, hypot(p1.x - p0.x, p1.y - p0.y)))
                d.position = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
                d.zRotation = atan2(p1.y - p0.y, p1.x - p0.x) - .pi / 2
                d.alpha = min(max(1 - z0 / Projector.maxDepth, 0), 1) * 0.85
            }
        }

        // Scrolling corridor gates give the speed a rhythm.
        let gs = Self.gateSpacing
        let gph = sim.worldZ.truncatingRemainder(dividingBy: gs)
        let roadHalf = W * 0.40
        for (i, g) in gates.enumerated() {
            let z = Double(i) * gs - gph
            if z < -Projector.cameraDistance * 0.5 || z > Projector.maxDepth {
                g.isHidden = true
                continue
            }
            g.isHidden = false
            let l = proj.project(x: W / 2 - roadHalf, z: z)
            let r = proj.project(x: W / 2 + roadHalf, z: z)
            g.size = CGSize(width: max(2, r.x - l.x), height: max(1, 2.2 * l.scale))
            g.position = CGPoint(x: W / 2, y: skY(l.y))
            g.alpha = min(max(1 - z / Projector.maxDepth, 0), 1) * 0.75
        }

        if !auroraLayer.isHidden {
            for (i, a) in auroras.enumerated() {
                let p = CGMutablePath()
                let fi = Double(i)
                p.move(to: CGPoint(x: -40, y: skY(HZ * 0.2 + fi * 20)))
                var x = -40.0
                while x <= W + 40 {
                    p.addLine(to: CGPoint(x: x, y: skY(HZ * 0.2 + fi * 24 + sin(x * 0.012 + time * 0.5 + fi) * 26)))
                    x += 28
                }
                p.addLine(to: CGPoint(x: W + 40, y: skY(HZ * 0.86)))
                p.addLine(to: CGPoint(x: -40, y: skY(HZ * 0.86)))
                p.closeSubpath()
                a.path = p
                a.alpha = 0.13 + 0.07 * sin(time * 0.6 + fi)
            }
        }

        if !dustLayer.isHidden {
            for (i, f) in dustBands.enumerated() {
                let y = HZ + 40 + (sim.fogPulse * 22 + Double(i) * 90).truncatingRemainder(dividingBy: H - HZ)
                f.position = CGPoint(x: W / 2, y: skY(y))
            }
        }

        if let boss = sim.boss, boss.isTelegraphing {
            if telegraphLane != boss.telegraphLane {
                telegraphLane = boss.telegraphLane
                let p0 = proj.project(lane: boss.telegraphLane, z: Projector.maxDepth * 0.8)
                let p1 = proj.project(lane: boss.telegraphLane, z: -40)
                let w0 = W * 0.24 * p0.scale, w1 = W * 0.24 * p1.scale
                let path = CGMutablePath()
                path.move(to: CGPoint(x: p0.x - w0 / 2, y: skY(p0.y)))
                path.addLine(to: CGPoint(x: p0.x + w0 / 2, y: skY(p0.y)))
                path.addLine(to: CGPoint(x: p1.x + w1 / 2, y: skY(p1.y)))
                path.addLine(to: CGPoint(x: p1.x - w1 / 2, y: skY(p1.y)))
                path.closeSubpath()
                telegraph.path = path
            }
            telegraph.isHidden = false
            telegraph.alpha = 0.16 + 0.20 * abs(sin(time * 1000 / 95))
        } else {
            telegraph.isHidden = true
            telegraphLane = -1
        }
    }
}
