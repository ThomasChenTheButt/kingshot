import SpriteKit

/// A hero on a stone pedestal beside the road, loosing arrows at nearby enemies.
final class HeroNode: SKNode {
    let spec: HeroSpec
    private let heroSprite = SKSpriteNode(texture: TextureFactory.shared.hero)

    init(spec: HeroSpec, track: TrackGeometry) {
        self.spec = spec
        super.init()
        // Stand just outside the cliff wall on the chosen bank.
        position = Units.point(track.point(s: spec.s, x: spec.side * 1.5))
        zPosition = 2

        let pedestal = SKSpriteNode(texture: TextureFactory.shared.pedestal)
        pedestal.zPosition = 0
        addChild(pedestal)

        heroSprite.position = CGPoint(x: 0, y: 26)
        heroSprite.zPosition = 1
        addChild(heroSprite)

        let bob = SKAction.sequence([.moveBy(x: 0, y: 2, duration: 0.6), .moveBy(x: 0, y: -2, duration: 0.6)])
        bob.timingMode = .easeInEaseOut
        heroSprite.run(.repeatForever(bob))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Fires an arrow towards `worldPoint` (in the parent's coordinate space).
    func fire(at worldPoint: CGPoint) {
        guard let parent else { return }
        let origin = parent.convert(heroSprite.position, from: self)
        let delta = worldPoint - origin
        let length = max(delta.magnitude, 1)

        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: 0, y: -9))
        arrowPath.addLine(to: CGPoint(x: 0, y: 9))
        let arrow = SKShapeNode(path: arrowPath)
        arrow.strokeColor = Palette.woodDark
        arrow.lineWidth = 3
        arrow.lineCap = .round
        arrow.position = origin
        arrow.zRotation = atan2(delta.y, delta.x) - .pi / 2
        arrow.zPosition = 12

        let tip = SKShapeNode(circleOfRadius: 2.5)
        tip.fillColor = Palette.steel
        tip.strokeColor = .clear
        tip.position = CGPoint(x: 0, y: 9)
        arrow.addChild(tip)
        parent.addChild(arrow)

        let duration = TimeInterval(min(0.35, Double(length) / 900))
        arrow.run(.sequence([.move(to: worldPoint, duration: duration), .fadeOut(withDuration: 0.05), .removeFromParent()]))

        heroSprite.removeAction(forKey: "recoil")
        heroSprite.run(.sequence([.scale(to: 1.12, duration: 0.05), .scale(to: 1.0, duration: 0.12)]), withKey: "recoil")
    }
}
