import SpriteKit

/// The player's horde: a round blob of little orange soldiers plus a headcount badge.
final class CrowdNode: SKNode {
    static let maxVisible = 140
    static let spacing: CGFloat = 5.6

    private var units: [SKSpriteNode] = []
    private var phases: [CGFloat] = []
    private var basePositions: [CGPoint] = []
    private let badge = CountBadge(fontSize: 22)
    private let texture = TextureFactory.shared.crowdUnit
    private(set) var count = 0

    override init() {
        super.init()
        badge.zPosition = 10
        addChild(badge)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var visualRadius: CGFloat {
        FormationLayout.blobRadius(count: min(count, CrowdNode.maxVisible), spacing: CrowdNode.spacing)
    }

    func setCount(_ newCount: Int, animateLosses: Bool = true) {
        let clamped = max(0, newCount)
        count = clamped
        let wanted = min(clamped, CrowdNode.maxVisible)

        while units.count < wanted {
            let index = units.count
            let sprite = SKSpriteNode(texture: texture)
            let base = FormationLayout.blobPosition(index: index, spacing: CrowdNode.spacing)
            sprite.position = base
            sprite.zPosition = (200 - base.y) * 0.001
            sprite.setScale(0)
            sprite.run(.scale(to: 1, duration: 0.15))
            addChild(sprite)
            units.append(sprite)
            basePositions.append(base)
            phases.append(CGFloat.random(in: 0...(2 * .pi)))
        }
        while units.count > wanted {
            let sprite = units.removeLast()
            basePositions.removeLast()
            phases.removeLast()
            if animateLosses, let parent {
                let worldPosition = convert(sprite.position, to: parent)
                sprite.removeFromParent()
                sprite.position = worldPosition
                sprite.zPosition = zPosition + 1
                parent.addChild(sprite)
                let fling = CGVector(dx: CGFloat.random(in: -18...18), dy: CGFloat.random(in: 10...30))
                sprite.run(.sequence([
                    .group([.move(by: fling, duration: 0.3), .fadeOut(withDuration: 0.3), .scale(to: 0.4, duration: 0.3)]),
                    .removeFromParent()
                ]))
            } else {
                sprite.removeFromParent()
            }
        }

        badge.setText("\(clamped)")
        badge.position = CGPoint(x: 0, y: visualRadius + 18)
        badge.pulse()
    }

    /// Running bob. Call every frame.
    func animate(time: TimeInterval) {
        let t = CGFloat(time)
        for (i, sprite) in units.enumerated() {
            let base = basePositions[i]
            sprite.position = CGPoint(x: base.x, y: base.y + sin(t * 14 + phases[i]) * 1.6)
        }
    }

    func celebrate() {
        for (i, sprite) in units.enumerated() {
            let delay = Double(i % 10) * 0.04
            let jump = SKAction.sequence([
                .wait(forDuration: delay),
                .moveBy(x: 0, y: 14, duration: 0.18),
                .moveBy(x: 0, y: -14, duration: 0.18)
            ])
            sprite.run(.repeatForever(jump), withKey: "celebrate")
        }
    }
}
