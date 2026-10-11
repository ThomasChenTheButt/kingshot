import SpriteKit

/// A number gate lying across (half of) the road: green buffs, red traps.
final class GateNode: SKNode {
    let spec: GateSpec
    private let panel: SKShapeNode

    init(spec: GateSpec, track: TrackGeometry) {
        self.spec = spec
        let laneWidth = Units.points(track.halfWidth * spec.lane.width) - 12
        let height: CGFloat = 46
        let rect = CGRect(x: -laneWidth / 2, y: -height / 2, width: laneWidth, height: height)
        panel = SKShapeNode(rect: rect, cornerRadius: 8)
        super.init()

        position = Units.point(track.point(s: spec.s, x: spec.lane.center))
        // Long axis across the road; "up" for the text points along the direction of travel.
        zRotation = CGFloat(track.tangent(atS: spec.s).angle) - .pi / 2
        zPosition = 1

        let good = spec.op.isPositive
        panel.fillColor = good ? Palette.gateGood : Palette.gateBad
        panel.strokeColor = good ? Palette.gateGoodEdge : Palette.gateBadEdge
        panel.lineWidth = 3
        addChild(panel)

        let dashPath = CGPath(roundedRect: rect.insetBy(dx: 6, dy: 6), cornerWidth: 5, cornerHeight: 5, transform: nil)
            .copy(dashingWithPhase: 0, lengths: [9, 6])
        let dashes = SKShapeNode(path: dashPath)
        dashes.strokeColor = UIColor(white: 1, alpha: 0.9)
        dashes.lineWidth = 2.5
        dashes.fillColor = .clear
        dashes.zPosition = 1
        addChild(dashes)

        let label = SKLabelNode(fontNamed: Fonts.heavy)
        label.text = spec.op.label
        label.fontSize = spec.lane == .full ? 32 : 28
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 2
        addChild(label)

        if good {
            let coin = SKSpriteNode(texture: TextureFactory.shared.coin)
            coin.size = CGSize(width: 16, height: 16)
            coin.position = CGPoint(x: -laneWidth / 2 + 16, y: -height / 2 + 13)
            coin.zPosition = 2
            addChild(coin)
        } else {
            let warning = SKLabelNode(fontNamed: Fonts.heavy)
            warning.text = "!"
            warning.fontSize = 18
            warning.fontColor = UIColor(white: 1, alpha: 0.9)
            warning.verticalAlignmentMode = .center
            warning.position = CGPoint(x: -laneWidth / 2 + 16, y: -height / 2 + 13)
            warning.zPosition = 2
            addChild(warning)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func hit() {
        let flash = SKAction.sequence([
            .run { [panel = self.panel] in panel.fillColor = .white },
            .wait(forDuration: 0.05),
            .run { [panel = self.panel, spec = self.spec] in panel.fillColor = spec.op.isPositive ? Palette.gateGood : Palette.gateBad }
        ])
        let pop = SKAction.sequence([.scale(to: 1.15, duration: 0.08), .scale(to: 0.0, duration: 0.25)])
        pop.timingMode = .easeIn
        run(.sequence([.group([flash, pop]), .removeFromParent()]))
    }
}
