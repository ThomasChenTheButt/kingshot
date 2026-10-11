import SpriteKit

/// A number on a dark pill, used above the crowd and above enemy formations.
final class CountBadge: SKNode {
    private let label = SKLabelNode(fontNamed: Fonts.heavy)
    private var pill = SKShapeNode()
    private let fill: UIColor

    init(fontSize: CGFloat, fill: UIColor = Palette.hudBadge) {
        self.fill = fill
        super.init()
        label.fontSize = fontSize
        label.fontColor = Palette.hudText
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        addChild(pill)
        addChild(label)
        setText("0")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setText(_ text: String) {
        guard label.text != text else { return }
        label.text = text
        let width = max(label.frame.width + 18, label.fontSize * 1.6)
        let height = label.fontSize * 1.35
        pill.removeFromParent()
        pill = SKShapeNode(rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
                           cornerRadius: height / 2)
        pill.fillColor = fill
        pill.strokeColor = .clear
        pill.zPosition = 0
        addChild(pill)
    }

    func pulse() {
        removeAction(forKey: "pulse")
        setScale(1)
        run(.sequence([.scale(to: 1.25, duration: 0.08), .scale(to: 1.0, duration: 0.12)]), withKey: "pulse")
    }
}
