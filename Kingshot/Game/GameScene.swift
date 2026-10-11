import SpriteKit
import UIKit

/// Orchestrates one level: builds the world from a `LevelSpec`, feeds input into the
/// `GameSimulation`, and turns its events into animation.
final class GameScene: SKScene {
    private enum Phase {
        case title
        case playing
        case finished
    }

    private var phase: Phase = .title
    private var level: LevelSpec?
    private var sim: GameSimulation?

    private let worldNode = SKNode()
    private let cameraNode = SKCameraNode()
    private let hud = HUDNode()
    private var crowd = CrowdNode()
    private var gateNodes: [Int: GateNode] = [:]
    private var enemyNodes: [Int: EnemyGroupNode] = [:]
    private var heroNodes: [Int: HeroNode] = [:]

    private var lastUpdateTime: TimeInterval = 0
    private var cameraScale: CGFloat = 1
    private var dragStartX: CGFloat = 0
    private var dragStartTarget: Double = 0
    private var coinsEarned = 0

    private let progress = ProgressStore.shared
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let notifier = UINotificationFeedbackGenerator()

    /// Points of horizontal drag that move the crowd one full lateral unit.
    private let steerPointsPerUnit: CGFloat = 120
    /// How far ahead of the crowd the camera looks, in track units.
    private let cameraLookAhead = 4.5
    /// Track units visible across the screen width.
    private let visibleUnits: CGFloat = 13.5

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = Palette.grass
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        if worldNode.parent == nil {
            addChild(worldNode)
            addChild(cameraNode)
            camera = cameraNode
            cameraNode.addChild(hud)
        }
        loadLevel(progress.level)
        layoutForSize()
        hud.showTitle(level: progress.level, bestLevel: progress.bestLevel)
        phase = .title
        impact.prepare()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard level != nil else { return }
        layoutForSize()
    }

    private func layoutForSize() {
        cameraScale = max(1, (visibleUnits * Units.pointsPerUnit) / max(size.width, 1))
        cameraNode.setScale(cameraScale)
        hud.layout(viewSize: size, cameraScale: cameraScale, safeInsets: view?.safeAreaInsets ?? .zero)
    }

    // MARK: Level setup

    private func loadLevel(_ number: Int) {
        worldNode.removeAllChildren()
        gateNodes.removeAll()
        enemyNodes.removeAll()
        heroNodes.removeAll()
        coinsEarned = 0

        let spec = LevelGenerator.makeLevel(number)
        let simulation = GameSimulation(level: spec)
        level = spec
        sim = simulation

        worldNode.addChild(TerrainBuilder.build(level: spec))
        for gate in spec.gates {
            let node = GateNode(spec: gate, track: spec.track)
            worldNode.addChild(node)
            gateNodes[gate.id] = node
        }
        for enemy in spec.enemies {
            let node = EnemyGroupNode(spec: enemy, track: spec.track)
            worldNode.addChild(node)
            enemyNodes[enemy.id] = node
        }
        for hero in spec.heroes {
            let node = HeroNode(spec: hero, track: spec.track)
            worldNode.addChild(node)
            heroNodes[hero.id] = node
        }

        crowd = CrowdNode()
        crowd.zPosition = 4
        worldNode.addChild(crowd)
        crowd.setCount(simulation.crowdCount, animateLosses: false)
        syncCrowd()
        cameraNode.position = cameraTarget()

        hud.setLevel(number)
        hud.setCoins(progress.coins)
        lastUpdateTime = 0
    }

    private func startGame() {
        guard let sim, phase != .playing else { return }
        hud.hideOverlay()
        phase = .playing
        sim.start()
        hud.showHint("Drag to steer")
    }

    // MARK: Frame update

    override func update(_ currentTime: TimeInterval) {
        let dt: TimeInterval = lastUpdateTime == 0 ? 1.0 / 60.0 : min(currentTime - lastUpdateTime, 1.0 / 30.0)
        lastUpdateTime = currentTime
        crowd.animate(time: currentTime)

        guard phase == .playing, let sim else { return }
        let events = sim.update(dt: dt)
        for event in events {
            handle(event)
        }
        syncCrowd()
        moveCamera(dt: dt)
    }

    private func syncCrowd() {
        guard let sim, let level else { return }
        crowd.position = Units.point(level.track.point(s: sim.crowdS, x: sim.crowdX))
    }

    private func cameraTarget() -> CGPoint {
        guard let sim, let level else { return .zero }
        return Units.point(level.track.position(atS: sim.crowdS + cameraLookAhead))
    }

    private func moveCamera(dt: TimeInterval) {
        let target = cameraTarget()
        let k = CGFloat(1 - exp(-dt * 5))
        cameraNode.position = cameraNode.position + (target - cameraNode.position) * k
    }

    // MARK: Simulation events

    private func handle(_ event: SimEvent) {
        guard let sim, let level else { return }
        switch event {
        case .gatePassed(let gateID, let op, _, let after):
            gateNodes[gateID]?.hit()
            gateNodes[gateID] = nil
            crowd.setCount(after)
            let color = op.isPositive ? Palette.coin : Palette.buttonRed
            FloatingText.show(op.label, at: crowd.position + CGPoint(x: 0, y: crowd.visualRadius + 40),
                              color: color, in: worldNode)
            if op.isPositive {
                impact.impactOccurred()
            } else {
                notifier.notificationOccurred(.warning)
            }

        case .battleStarted(let enemyID):
            enemyNodes[enemyID]?.flash()
            impact.impactOccurred(intensity: 0.7)

        case .unitsTraded(let enemyID, _, _):
            crowd.setCount(sim.crowdCount)
            enemyNodes[enemyID]?.setCount(sim.enemyCount(enemyID))

        case .enemyDefeated(let enemyID):
            if let node = enemyNodes[enemyID] {
                let reward = max(1, node.spec.count / 2)
                coinsEarned += reward
                FloatingText.show("+\(reward)", at: node.position + CGPoint(x: 0, y: 30),
                                  color: Palette.coin, fontSize: 24, in: worldNode)
                node.defeated()
                enemyNodes[enemyID] = nil
            }

        case .heroFired(let heroID, let enemyID, _):
            if let enemyNode = enemyNodes[enemyID] {
                heroNodes[heroID]?.fire(at: enemyNode.targetPoint)
                enemyNode.setCount(sim.enemyCount(enemyID))
                enemyNode.flash()
            }

        case .won(let survivors):
            phase = .finished
            coinsEarned += survivors + 5 * level.level
            progress.coins += coinsEarned
            progress.level = level.level + 1
            hud.setCoins(progress.coins)
            crowd.celebrate()
            notifier.notificationOccurred(.success)
            let levelNumber = level.level
            let earned = coinsEarned
            run(.sequence([.wait(forDuration: 1.2), .run { [weak self] in
                self?.hud.showResult(won: true, level: levelNumber, survivors: survivors, coinsEarned: earned)
            }]))

        case .lost:
            phase = .finished
            crowd.setCount(0)
            notifier.notificationOccurred(.error)
            let levelNumber = level.level
            run(.sequence([.wait(forDuration: 1.0), .run { [weak self] in
                self?.hud.showResult(won: false, level: levelNumber, survivors: 0, coinsEarned: 0)
            }]))
        }
    }

    // MARK: Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let hudPoint = touch.location(in: hud)
        switch phase {
        case .title:
            startGame()
        case .finished:
            guard let button = hud.button(at: hudPoint) else { return }
            if button == HUDNode.Button.next || button == HUDNode.Button.retry {
                loadLevel(progress.level)
                hud.hideOverlay()
                phase = .title
                startGame()
            }
        case .playing:
            dragStartX = hudPoint.x
            dragStartTarget = sim?.targetX ?? 0
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .playing, let touch = touches.first, let sim else { return }
        let x = touch.location(in: hud).x
        let delta = Double((x - dragStartX) / steerPointsPerUnit)
        sim.targetX = min(1, max(-1, dragStartTarget + delta))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Steering holds its last position; nothing to release.
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}
