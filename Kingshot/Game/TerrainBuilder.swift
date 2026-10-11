import SpriteKit

/// Draws the map: grass, cliff walls, sandy road, trees, the start camp and the boss keep.
enum TerrainBuilder {
    static let wallThickness: Double = 1.15   // track units on each side of the road

    static func build(level: LevelSpec) -> SKNode {
        let root = SKNode()
        let track = level.track
        var rng = SplitMix64(seed: level.seed ^ 0x7E44_A1B2_C3D4_E5F6)

        let roadPath = CGMutablePath()
        for (i, sample) in track.samplePositions.enumerated() {
            let p = Units.point(sample)
            if i == 0 { roadPath.move(to: p) } else { roadPath.addLine(to: p) }
        }

        let roadWidth = Units.points(track.halfWidth * 2)
        let wallWidth = roadWidth + Units.points(wallThickness * 2)

        func stroke(_ color: UIColor, width: CGFloat, z: CGFloat, offset: CGPoint = .zero) {
            let node = SKShapeNode(path: roadPath)
            node.strokeColor = color
            node.fillColor = .clear
            node.lineWidth = width
            node.lineCap = .round
            node.lineJoin = .round
            node.zPosition = z
            node.position = offset
            root.addChild(node)
        }

        stroke(Palette.shadow, width: wallWidth + 14, z: -5, offset: CGPoint(x: 10, y: -14))
        stroke(Palette.cliffDark, width: wallWidth + 6, z: -4)
        stroke(Palette.cliff, width: wallWidth, z: -3)
        stroke(Palette.cliffLight, width: wallWidth - Units.points(wallThickness * 0.9), z: -2.5)
        stroke(Palette.sand, width: roadWidth, z: -2)
        stroke(Palette.sandLight.withAlphaComponent(0.55), width: roadWidth * 0.55, z: -1.9)

        addTrees(to: root, track: track, rng: &rng)
        addStartCamp(to: root, track: track)
        addKeep(to: root, level: level)
        return root
    }

    private static func addTrees(to root: SKNode, track: TrackGeometry, rng: inout SplitMix64) {
        let bounds = track.bounds
        let margin = 9.0
        let clearance = track.halfWidth + wallThickness + 1.0
        var placed = 0
        var attempts = 0
        while placed < 70 && attempts < 400 {
            attempts += 1
            let p = Vec2(Double.random(in: (bounds.min.x - margin)...(bounds.max.x + margin), using: &rng),
                         Double.random(in: (bounds.min.y - margin)...(bounds.max.y + margin), using: &rng))
            guard track.distanceToCenterline(p) > clearance else { continue }
            placed += 1
            let radius = Units.points(Double.random(in: 0.45...0.95, using: &rng))
            let center = Units.point(p)

            let shadow = SKShapeNode(circleOfRadius: radius)
            shadow.fillColor = Palette.shadow
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: center.x + 5, y: center.y - 6)
            shadow.zPosition = -1.5
            root.addChild(shadow)

            let canopy = SKShapeNode(circleOfRadius: radius)
            canopy.fillColor = Palette.grassDark
            canopy.strokeColor = .clear
            canopy.position = center
            canopy.zPosition = -1.4
            root.addChild(canopy)

            let highlight = SKShapeNode(circleOfRadius: radius * 0.55)
            highlight.fillColor = Palette.treeLight
            highlight.strokeColor = .clear
            highlight.position = CGPoint(x: center.x - radius * 0.25, y: center.y + radius * 0.25)
            highlight.zPosition = -1.3
            root.addChild(highlight)
        }
    }

    /// Wooden lumber camp near the start, like the hut in the top corner of the Kingshot map.
    private static func addStartCamp(to root: SKNode, track: TrackGeometry) {
        let camp = SKNode()
        camp.position = Units.point(track.point(s: -5, x: 2.4))
        camp.zPosition = -1.2

        let shadow = SKShapeNode(rect: CGRect(x: -36, y: -34, width: 80, height: 60), cornerRadius: 8)
        shadow.fillColor = Palette.shadow
        shadow.strokeColor = .clear
        camp.addChild(shadow)

        let floor = SKShapeNode(rect: CGRect(x: -40, y: -28, width: 80, height: 60), cornerRadius: 8)
        floor.fillColor = Palette.woodDark
        floor.strokeColor = .clear
        camp.addChild(floor)

        for i in 0..<5 {
            let plank = SKShapeNode(rect: CGRect(x: -36, y: CGFloat(-24 + i * 11), width: 72, height: 8), cornerRadius: 2)
            plank.fillColor = Palette.wood
            plank.strokeColor = .clear
            plank.zPosition = 1
            camp.addChild(plank)
        }
        for (dx, dy) in [(-32, -20), (32, -20), (-32, 24), (32, 24)] {
            let post = SKShapeNode(circleOfRadius: 5)
            post.fillColor = Palette.woodDark
            post.strokeColor = .clear
            post.position = CGPoint(x: dx, y: dy)
            post.zPosition = 2
            camp.addChild(post)
        }
        root.addChild(camp)
    }

    /// Stone keep behind the boss formation at the end of the road.
    private static func addKeep(to root: SKNode, level: LevelSpec) {
        let track = level.track
        let s = level.length - 1
        let keep = SKNode()
        keep.position = Units.point(track.position(atS: s))
        keep.zRotation = CGFloat(track.tangent(atS: s).angle) - .pi / 2
        keep.zPosition = -1.1

        let width = Units.points(track.halfWidth * 2) + 20
        let wall = SKShapeNode(rect: CGRect(x: -width / 2, y: -20, width: width, height: 70), cornerRadius: 10)
        wall.fillColor = Palette.cliffDark
        wall.strokeColor = Palette.cliff
        wall.lineWidth = 4
        keep.addChild(wall)

        let battlements = Int(width / 28)
        for i in 0..<battlements {
            let x = -width / 2 + 14 + CGFloat(i) * 28
            let merlon = SKShapeNode(rect: CGRect(x: x - 8, y: 46, width: 16, height: 16), cornerRadius: 3)
            merlon.fillColor = Palette.cliff
            merlon.strokeColor = .clear
            keep.addChild(merlon)
        }

        let banner = SKShapeNode(rect: CGRect(x: -14, y: -4, width: 28, height: 40), cornerRadius: 4)
        banner.fillColor = Palette.gateBad
        banner.strokeColor = Palette.gateBadEdge
        banner.lineWidth = 2
        banner.zPosition = 1
        keep.addChild(banner)

        root.addChild(keep)
    }
}
