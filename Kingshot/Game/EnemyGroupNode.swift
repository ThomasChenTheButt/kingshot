import SpriteKit

/// A red formation blocking the road. Laid out in ranks facing the oncoming crowd.
final class EnemyGroupNode: SKNode {
    static let maxVisible = 72
    static let spacing: CGFloat = 9

    let spec: EnemyGroupSpec
    private var units: [SKSpriteNode] = []
    private let badge: CountBadge
    private let forward: CGVector
    private let right: CGVector
    private(set) var count: Int
    private let columns: Int

    init(spec: EnemyGroupSpec, track: TrackGeometry) {
        self.spec = spec
        self.count = spec.count
        let tangent = track.tangent(atS: spec.s)
        forward = CGVector(dx: CGFloat(tangent.x), dy: CGFloat(tangent.y))
        let perp = tangent.rightPerpendicular
        right = CGVector(dx: CGFloat(perp.x), dy: CGFloat(perp.y))
        let maxColumns = Int((Units.points(track.halfWidth * spec.halfWidth * 2) - 10) / EnemyGroupNode.spacing)
        columns = max(2, min(maxColumns, spec.isBoss ? 10 : 6, spec.count))
        badge = CountBadge(fontSize: spec.isBoss ? 26 : 20,
                           fill: spec.isBoss ? Palette.gateBadEdge.withAlphaComponent(0.85) : Palette.hudBadge)
        super.init()
        position = Units.point(track.point(s: spec.s, x: spec.x))
        zPosition = 3

        if spec.isBoss {
            let platformWidth = Units.points(track.halfWidth * 2) - 8
            let platform = SKShapeNode(rect: CGRect(x: -platformWidth / 2, y: -30, width: platformWidth, height: 110),
                                       cornerRadius: 14)
            platform.fillColor = Palette.cliffDark.withAlphaComponent(0.35)
            platform.strokeColor = Palette.cliffDark.withAlphaComponent(0.6)
            platform.lineWidth = 3
            platform.zRotation = CGFloat(tangent.angle) - .pi / 2
            platform.zPosition = -1
            addChild(platform)
        }

        rebuildUnits()
        badge.zPosition = 10
        addChild(badge)
        updateBadge()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// World-space point an arrow should fly to.
    var targetPoint: CGPoint {
        guard let last = units.first, let parent else { return position }
        return convert(last.position, to: parent)
    }

    private func rebuildUnits() {
        let wanted = min(count, EnemyGroupNode.maxVisible)
        while units.count < wanted {
            let index = units.count
            let sprite = SKSpriteNode(texture: TextureFactory.shared.enemyUnit)
            let offset = FormationLayout.gridOffset(index: index, columns: columns, spacing: EnemyGroupNode.spacing)
            sprite.position = CGPoint(x: right.dx * offset.across + forward.dx * offset.back,
                                      y: right.dy * offset.across + forward.dy * offset.back)
            sprite.zPosition = (400 - sprite.position.y) * 0.001
            if spec.isBoss { sprite.setScale(1.15) }
            addChild(sprite)
            units.append(sprite)
        }
    }

    private func updateBadge() {
        let depth = CGFloat((min(count, EnemyGroupNode.maxVisible) + columns - 1) / columns) * EnemyGroupNode.spacing
        let anchor = CGPoint(x: forward.dx * depth * 0.5, y: forward.dy * depth * 0.5)
        badge.position = CGPoint(x: anchor.x, y: anchor.y + depth * 0.5 + 26)
        badge.setText(spec.isBoss ? "BOSS \(count)" : "\(count)")
    }

    func setCount(_ newCount: Int) {
        let clamped = max(0, newCount)
        guard clamped != count else { return }
        let lost = count - clamped
        count = clamped
        let wanted = min(clamped, EnemyGroupNode.maxVisible)
        var removed = 0
        while units.count > wanted {
            let sprite = units.removeLast()
            removed += 1
            if removed <= 12, let parent {
                let worldPosition = convert(sprite.position, to: parent)
                sprite.removeFromParent()
                sprite.position = worldPosition
                sprite.zPosition = zPosition + 1
                parent.addChild(sprite)
                let fling = CGVector(dx: CGFloat.random(in: -16...16), dy: CGFloat.random(in: 8...26))
                sprite.run(.sequence([
                    .group([.move(by: fling, duration: 0.28), .fadeOut(withDuration: 0.28), .scale(to: 0.3, duration: 0.28)]),
                    .removeFromParent()
                ]))
            } else {
                sprite.removeFromParent()
            }
        }
        if lost > 0 { badge.pulse() }
        updateBadge()
    }

    func flash() {
        for sprite in units.prefix(columns) {
            sprite.removeAction(forKey: "flash")
            sprite.run(.sequence([.colorize(with: .white, colorBlendFactor: 0.7, duration: 0.04),
                                  .colorize(withColorBlendFactor: 0, duration: 0.12)]), withKey: "flash")
        }
    }

    func defeated() {
        setCount(0)
        badge.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        run(.sequence([.wait(forDuration: 0.5), .removeFromParent()]))
    }
}
