import SpriteKit

/// Heads-up display and overlays. Lives on the camera so it ignores world movement.
final class HUDNode: SKNode {
    enum Button {
        static let play = "btn_play"
        static let next = "btn_next"
        static let retry = "btn_retry"
    }

    private let levelLabel = SKLabelNode(fontNamed: Fonts.heavy)
    private let coinLabel = SKLabelNode(fontNamed: Fonts.heavy)
    private let coinIcon = SKSpriteNode(texture: TextureFactory.shared.coin)
    private let hintLabel = SKLabelNode(fontNamed: Fonts.demi)
    private let overlay = SKNode()

    private var viewSize = CGSize(width: 390, height: 844)
    private var cameraScale: CGFloat = 1
    private var safeInsets = UIEdgeInsets.zero

    override init() {
        super.init()
        zPosition = 100

        levelLabel.fontSize = 24
        levelLabel.fontColor = Palette.hudText
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.verticalAlignmentMode = .top
        addChild(levelLabel)

        coinLabel.fontSize = 22
        coinLabel.fontColor = Palette.coin
        coinLabel.horizontalAlignmentMode = .right
        coinLabel.verticalAlignmentMode = .top
        addChild(coinLabel)

        coinIcon.size = CGSize(width: 22, height: 22)
        addChild(coinIcon)

        hintLabel.fontSize = 20
        hintLabel.fontColor = UIColor(white: 1, alpha: 0.95)
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.verticalAlignmentMode = .center
        hintLabel.alpha = 0
        addChild(hintLabel)

        addChild(overlay)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // Camera-space extents (camera scale enlarges children, so divide the view size out).
    private var halfWidth: CGFloat { viewSize.width / cameraScale / 2 }
    private var halfHeight: CGFloat { viewSize.height / cameraScale / 2 }

    func layout(viewSize: CGSize, cameraScale: CGFloat, safeInsets: UIEdgeInsets) {
        self.viewSize = viewSize
        self.cameraScale = cameraScale
        self.safeInsets = safeInsets

        let top = halfHeight - (safeInsets.top + 12) / cameraScale
        let left = -halfWidth + 18
        let right = halfWidth - 18
        levelLabel.position = CGPoint(x: left, y: top)
        coinLabel.position = CGPoint(x: right, y: top)
        coinIcon.position = CGPoint(x: right - coinLabel.frame.width - 18, y: top - 12)
        hintLabel.position = CGPoint(x: 0, y: -halfHeight + (safeInsets.bottom + 60) / cameraScale)
    }

    func setLevel(_ level: Int) {
        levelLabel.text = "LEVEL \(level)"
    }

    func setCoins(_ coins: Int) {
        coinLabel.text = "\(coins)"
        coinIcon.position = CGPoint(x: coinLabel.position.x - coinLabel.frame.width - 18, y: coinLabel.position.y - 12)
    }

    func showHint(_ text: String, duration: TimeInterval = 2.5) {
        hintLabel.text = text
        hintLabel.removeAllActions()
        hintLabel.alpha = 0
        hintLabel.run(.sequence([.fadeIn(withDuration: 0.2), .wait(forDuration: duration), .fadeOut(withDuration: 0.4)]))
    }

    // MARK: Overlays

    func hideOverlay() {
        overlay.removeAllChildren()
    }

    func showTitle(level: Int, bestLevel: Int) {
        hideOverlay()
        addDim()
        let title = makeLabel("KINGSHOT", size: 54, color: Palette.coin, font: Fonts.heavy)
        title.position = CGPoint(x: 0, y: 150)
        overlay.addChild(title)
        let shadow = makeLabel("KINGSHOT", size: 54, color: UIColor(white: 0, alpha: 0.5), font: Fonts.heavy)
        shadow.position = CGPoint(x: 3, y: 146)
        shadow.zPosition = -1
        overlay.addChild(shadow)

        let subtitle = makeLabel("Road to the Keep", size: 22, color: .white, font: Fonts.demi)
        subtitle.position = CGPoint(x: 0, y: 108)
        overlay.addChild(subtitle)

        let levelText = makeLabel("Level \(level)   •   Best \(bestLevel)", size: 18,
                                  color: UIColor(white: 1, alpha: 0.85), font: Fonts.demi)
        levelText.position = CGPoint(x: 0, y: 70)
        overlay.addChild(levelText)

        overlay.addChild(makeButton("TAP TO PLAY", name: Button.play, color: Palette.buttonGreen, y: -20))

        let help = makeLabel("Hold and drag to steer your army", size: 16, color: UIColor(white: 1, alpha: 0.8), font: Fonts.demi)
        help.position = CGPoint(x: 0, y: -90)
        overlay.addChild(help)
        let help2 = makeLabel("Take green gates, dodge red ones, outnumber the boss", size: 14,
                              color: UIColor(white: 1, alpha: 0.7), font: Fonts.demi)
        help2.position = CGPoint(x: 0, y: -114)
        overlay.addChild(help2)
    }

    func showResult(won: Bool, level: Int, survivors: Int, coinsEarned: Int) {
        hideOverlay()
        addDim()
        let panelWidth = min(330, halfWidth * 2 - 40)
        let panel = SKShapeNode(rect: CGRect(x: -panelWidth / 2, y: -140, width: panelWidth, height: 290), cornerRadius: 22)
        panel.fillColor = Palette.panel
        panel.strokeColor = won ? Palette.coin : Palette.buttonRed
        panel.lineWidth = 4
        overlay.addChild(panel)

        let heading = makeLabel(won ? "VICTORY!" : "DEFEATED", size: 42,
                                color: won ? Palette.coin : Palette.buttonRed, font: Fonts.heavy)
        heading.position = CGPoint(x: 0, y: 90)
        overlay.addChild(heading)

        let line1 = makeLabel(won ? "Level \(level) cleared" : "Level \(level) failed", size: 20, color: .white, font: Fonts.demi)
        line1.position = CGPoint(x: 0, y: 48)
        overlay.addChild(line1)

        let line2 = makeLabel(won ? "\(survivors) soldiers survived" : "Your army was wiped out",
                              size: 17, color: UIColor(white: 1, alpha: 0.8), font: Fonts.demi)
        line2.position = CGPoint(x: 0, y: 18)
        overlay.addChild(line2)

        if won {
            let reward = makeLabel("+\(coinsEarned)", size: 26, color: Palette.coin, font: Fonts.heavy)
            reward.position = CGPoint(x: 10, y: -24)
            overlay.addChild(reward)
            let icon = SKSpriteNode(texture: TextureFactory.shared.coin)
            icon.size = CGSize(width: 24, height: 24)
            icon.position = CGPoint(x: -reward.frame.width / 2 - 8, y: -24)
            overlay.addChild(icon)
        }

        overlay.addChild(makeButton(won ? "NEXT LEVEL" : "TRY AGAIN",
                                    name: won ? Button.next : Button.retry,
                                    color: won ? Palette.buttonGreen : Palette.buttonRed,
                                    y: -92))
    }

    /// Name of the button under `point` (in HUD coordinates), if any.
    func button(at point: CGPoint) -> String? {
        for node in nodes(at: point) {
            if let name = node.name, name.hasPrefix("btn_") { return name }
        }
        return nil
    }

    // MARK: Builders

    private func addDim() {
        let dim = SKShapeNode(rect: CGRect(x: -3000, y: -3000, width: 6000, height: 6000))
        dim.fillColor = UIColor(white: 0, alpha: 0.45)
        dim.strokeColor = .clear
        dim.zPosition = -2
        overlay.addChild(dim)
    }

    private func makeLabel(_ text: String, size: CGFloat, color: UIColor, font: String) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: font)
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        return label
    }

    private func makeButton(_ text: String, name: String, color: UIColor, y: CGFloat) -> SKNode {
        let width: CGFloat = 230
        let height: CGFloat = 60
        let button = SKShapeNode(rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), cornerRadius: 16)
        button.fillColor = color
        button.strokeColor = UIColor(white: 1, alpha: 0.85)
        button.lineWidth = 3
        button.name = name
        button.position = CGPoint(x: 0, y: y)

        let label = makeLabel(text, size: 24, color: .white, font: Fonts.heavy)
        label.name = name
        label.zPosition = 1
        button.addChild(label)

        let pulse = SKAction.sequence([.scale(to: 1.05, duration: 0.5), .scale(to: 1.0, duration: 0.5)])
        pulse.timingMode = .easeInEaseOut
        button.run(.repeatForever(pulse))
        return button
    }
}
