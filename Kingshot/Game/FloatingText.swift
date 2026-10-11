import SpriteKit

enum FloatingText {
    /// Spawns a label that drifts upwards and fades, e.g. "+20" when a gate is taken.
    static func show(_ text: String, at position: CGPoint, color: UIColor, fontSize: CGFloat = 30,
                     in parent: SKNode, rise: CGFloat = 70, duration: TimeInterval = 0.9) {
        let shadow = SKLabelNode(fontNamed: Fonts.heavy)
        shadow.text = text
        shadow.fontSize = fontSize
        shadow.fontColor = UIColor(white: 0, alpha: 0.5)
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.verticalAlignmentMode = .center
        shadow.horizontalAlignmentMode = .center

        let label = SKLabelNode(fontNamed: Fonts.heavy)
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        let holder = SKNode()
        holder.position = position
        holder.zPosition = 30
        holder.addChild(shadow)
        holder.addChild(label)
        holder.setScale(0.6)
        parent.addChild(holder)

        let pop = SKAction.scale(to: 1.0, duration: 0.12)
        pop.timingMode = .easeOut
        let drift = SKAction.moveBy(x: 0, y: rise, duration: duration)
        drift.timingMode = .easeOut
        let fade = SKAction.sequence([.wait(forDuration: duration * 0.5), .fadeOut(withDuration: duration * 0.5)])
        holder.run(.sequence([pop, .group([drift, fade]), .removeFromParent()]))
    }
}
