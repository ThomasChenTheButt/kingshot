import SpriteKit
import UIKit

/// Draws every sprite the game needs with Core Graphics, once, so the app has no image assets.
final class TextureFactory {
    static let shared = TextureFactory()

    private(set) lazy var crowdUnit: SKTexture = makeUnit(body: Palette.crowdBody, bodyEdge: Palette.crowdBodyDark,
                                                           head: Palette.crowdHead, helmet: nil)
    private(set) lazy var enemyUnit: SKTexture = makeUnit(body: Palette.enemyBody, bodyEdge: Palette.enemyBodyDark,
                                                           head: Palette.enemyHead, helmet: Palette.enemyHelmet)
    private(set) lazy var hero: SKTexture = makeHero()
    private(set) lazy var pedestal: SKTexture = makePedestal()
    private(set) lazy var coin: SKTexture = makeCoin()

    private func render(size: CGSize, _ draw: (CGContext) -> Void) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            draw(context.cgContext)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private func makeUnit(body: UIColor, bodyEdge: UIColor, head: UIColor, helmet: UIColor?) -> SKTexture {
        render(size: CGSize(width: 18, height: 22)) { c in
            // Drop shadow
            c.setFillColor(Palette.shadow.cgColor)
            c.fillEllipse(in: CGRect(x: 3, y: 15, width: 12, height: 6))
            // Body
            let bodyRect = CGRect(x: 4, y: 7, width: 10, height: 11)
            c.setFillColor(bodyEdge.cgColor)
            c.addPath(UIBezierPath(roundedRect: bodyRect, cornerRadius: 4).cgPath)
            c.fillPath()
            c.setFillColor(body.cgColor)
            c.addPath(UIBezierPath(roundedRect: bodyRect.insetBy(dx: 1.2, dy: 1.2), cornerRadius: 3).cgPath)
            c.fillPath()
            // Head
            c.setFillColor(head.cgColor)
            c.fillEllipse(in: CGRect(x: 5, y: 1.5, width: 8, height: 8))
            if let helmet {
                c.setFillColor(helmet.cgColor)
                c.addPath(UIBezierPath(roundedRect: CGRect(x: 4.5, y: 1, width: 9, height: 5), cornerRadius: 2.5).cgPath)
                c.fillPath()
            }
        }
    }

    private func makeHero() -> SKTexture {
        render(size: CGSize(width: 44, height: 56)) { c in
            // Shadow
            c.setFillColor(Palette.shadow.cgColor)
            c.fillEllipse(in: CGRect(x: 8, y: 46, width: 28, height: 9))
            // Legs
            c.setFillColor(Palette.woodDark.cgColor)
            c.fill(CGRect(x: 15, y: 38, width: 5, height: 10))
            c.fill(CGRect(x: 24, y: 38, width: 5, height: 10))
            // Tunic
            c.setFillColor(Palette.heroTunic.cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 11, y: 20, width: 22, height: 22), cornerRadius: 7).cgPath)
            c.fillPath()
            // Belt
            c.setFillColor(Palette.heroGold.cgColor)
            c.fill(CGRect(x: 11, y: 33, width: 22, height: 3))
            // Sword (diagonal)
            c.setStrokeColor(Palette.steel.cgColor)
            c.setLineWidth(3.5)
            c.setLineCap(.round)
            c.move(to: CGPoint(x: 30, y: 30))
            c.addLine(to: CGPoint(x: 42, y: 8))
            c.strokePath()
            c.setStrokeColor(Palette.heroGold.cgColor)
            c.setLineWidth(3)
            c.move(to: CGPoint(x: 27, y: 32))
            c.addLine(to: CGPoint(x: 33, y: 29))
            c.strokePath()
            // Shield
            c.setFillColor(Palette.steel.cgColor)
            c.fillEllipse(in: CGRect(x: 2, y: 24, width: 12, height: 15))
            c.setFillColor(Palette.heroTunic.cgColor)
            c.fillEllipse(in: CGRect(x: 5, y: 28, width: 6, height: 7))
            // Head
            c.setFillColor(Palette.heroSkin.cgColor)
            c.fillEllipse(in: CGRect(x: 14, y: 8, width: 16, height: 16))
            // Golden helmet with plume
            c.setFillColor(Palette.heroGold.cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 12, y: 5, width: 20, height: 11), cornerRadius: 6).cgPath)
            c.fillPath()
            c.setFillColor(Palette.gateBad.cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 19, y: 0, width: 6, height: 9), cornerRadius: 3).cgPath)
            c.fillPath()
        }
    }

    private func makePedestal() -> SKTexture {
        render(size: CGSize(width: 64, height: 80)) { c in
            // Shadow
            c.setFillColor(Palette.shadow.cgColor)
            c.fillEllipse(in: CGRect(x: 6, y: 64, width: 56, height: 14))
            // Column body
            c.setFillColor(Palette.cliffDark.cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 10, y: 10, width: 44, height: 62), cornerRadius: 6).cgPath)
            c.fillPath()
            c.setFillColor(Palette.cliff.cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 13, y: 10, width: 38, height: 54), cornerRadius: 5).cgPath)
            c.fillPath()
            // Top face
            c.setFillColor(Palette.cliffLight.cgColor)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 6, y: 2, width: 52, height: 22), cornerRadius: 6).cgPath)
            c.fillPath()
            // Carved face details
            c.setFillColor(Palette.cliffDark.withAlphaComponent(0.6).cgColor)
            c.fill(CGRect(x: 22, y: 36, width: 5, height: 5))
            c.fill(CGRect(x: 37, y: 36, width: 5, height: 5))
            c.fill(CGRect(x: 26, y: 47, width: 12, height: 3))
        }
    }

    private func makeCoin() -> SKTexture {
        render(size: CGSize(width: 20, height: 20)) { c in
            c.setFillColor(Palette.coinDark.cgColor)
            c.fillEllipse(in: CGRect(x: 0, y: 0, width: 20, height: 20))
            c.setFillColor(Palette.coin.cgColor)
            c.fillEllipse(in: CGRect(x: 2, y: 2, width: 16, height: 16))
            c.setFillColor(Palette.coinDark.cgColor)
            c.fillEllipse(in: CGRect(x: 6, y: 6, width: 8, height: 8))
            c.setFillColor(Palette.coin.cgColor)
            c.fillEllipse(in: CGRect(x: 7.5, y: 7.5, width: 5, height: 5))
        }
    }
}
