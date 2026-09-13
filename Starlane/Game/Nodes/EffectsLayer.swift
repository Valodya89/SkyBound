import SpriteKit
import StarlaneCore

/// Particles, expanding rings and floating score text. Everything here is fire-and-forget.
final class EffectsLayer: SKNode {
    private let textures: TextureFactory
    private var rng = SystemRandomSource()

    init(textures: TextureFactory) {
        self.textures = textures
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func burst(at point: CGPoint, color: SKColor, count: Int, speed: Double = 3, size: Double = 3) {
        let frames = 45.0
        for _ in 0..<count {
            let a = rng.next(in: 0...(2 * .pi)), v = rng.next(in: 0.4...1) * speed
            let vx = cos(a) * v, vy = -(sin(a) * v - 0.6)
            let p = SKSpriteNode(texture: textures.dot)
            p.color = color
            p.colorBlendFactor = 1
            let s = size * rng.next(in: 0.6...1.3) * 1.1
            p.size = CGSize(width: s, height: s)
            p.position = point
            let dx = vx * frames, dy = vy * frames - 0.5 * 0.11 * frames * frames
            let move = SKAction.move(by: CGVector(dx: dx, dy: dy), duration: frames / 60)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: frames / 60)
            p.run(.sequence([.group([move, fade]), .removeFromParent()]))
            addChild(p)
        }
    }

    func ring(at point: CGPoint, radius: Double, color: SKColor) {
        let n = SKShapeNode(circleOfRadius: radius)
        n.strokeColor = color
        n.lineWidth = 3.4
        n.fillColor = .clear
        n.alpha = 0.65
        n.position = point
        let frames = 28.0
        let grow = SKAction.scale(to: (radius + 6 * frames) / radius, duration: frames / 60)
        grow.timingMode = .easeOut
        n.run(.sequence([.group([grow, .fadeOut(withDuration: frames / 60)]), .removeFromParent()]))
        addChild(n)
    }

    func floatText(_ text: String, at point: CGPoint, color: SKColor, big: Bool = false) {
        let size: CGFloat = big ? 26 : 18
        let l = SceneFont.label(text, size: size, color: color)
        l.position = point
        l.zPosition = 10
        let shadow = SceneFont.label(text, size: size, color: SKColor.black.withAlphaComponent(0.35))
        shadow.position = CGPoint(x: 1.5, y: -1.5)
        shadow.zPosition = -1
        l.addChild(shadow)
        let frames = 53.0
        l.run(.sequence([.group([.moveBy(x: 0, y: 1.1 * frames, duration: frames / 60), .fadeOut(withDuration: frames / 60)]), .removeFromParent()]))
        addChild(l)
    }
}
