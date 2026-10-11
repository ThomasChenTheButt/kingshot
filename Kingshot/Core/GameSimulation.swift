import Foundation

public enum SimState: Equatable {
    case ready
    case running
    case fighting
    case won
    case lost
}

/// Discrete things that happened during a tick, for the scene to animate.
public enum SimEvent: Equatable {
    case gatePassed(gateID: Int, op: GateOp, before: Int, after: Int)
    case battleStarted(enemyID: Int)
    case unitsTraded(enemyID: Int, crowdLost: Int, enemyLost: Int)
    case enemyDefeated(enemyID: Int)
    case heroFired(heroID: Int, enemyID: Int, damage: Int)
    case won(survivors: Int)
    case lost
}

/// Pure, deterministic game-rules engine. No rendering, no timers: call `update(dt:)`.
public final class GameSimulation {
    public let level: LevelSpec

    public private(set) var state: SimState = .ready
    public private(set) var crowdCount: Int
    public private(set) var crowdS: Double = 0
    public private(set) var crowdX: Double = 0
    public private(set) var elapsed: Double = 0
    public private(set) var passedGateIDs: Set<Int> = []
    public private(set) var engagedEnemyID: Int?
    public private(set) var enemyCounts: [Int: Int]
    public private(set) var enemiesDefeated = 0

    /// Where the player wants the crowd to be laterally (-1...1). Set from input.
    public var targetX: Double = 0

    /// Tuning constants shared with `LevelGenerator`, which sizes obstacles by running the
    /// simulation itself.
    public enum Defaults {
        public static let forwardSpeed = 7.5          // track units per second
        public static let lateralSpeed = 3.5          // lateral units per second
        public static let engageDistance = 1.4        // track units ahead at which a battle starts
        public static let tradeInterval = 0.05        // seconds between unit trades in a battle
        public static let heroActivationFactor = 1.5  // heroes wake up within range × this of the crowd
        public static let tickRate = 60.0             // steps per second used for offline measurement
    }

    public var forwardSpeed = Defaults.forwardSpeed
    public var lateralSpeed = Defaults.lateralSpeed
    public var engageDistance = Defaults.engageDistance
    public var tradeInterval = Defaults.tradeInterval

    private var heroCooldowns: [Int: Double] = [:]
    private var tradeAccumulator: Double = 0

    public init(level: LevelSpec) {
        self.level = level
        crowdCount = level.startCount
        enemyCounts = Dictionary(uniqueKeysWithValues: level.enemies.map { ($0.id, $0.count) })
        for hero in level.heroes {
            heroCooldowns[hero.id] = hero.fireInterval * 0.5
        }
    }

    /// Lateral half extent of the crowd blob, in lateral units. Grows with the headcount.
    public var crowdHalfWidth: Double {
        min(0.5, 0.12 + 0.035 * Double(max(crowdCount, 1)).squareRoot())
    }

    public var crowdRange: ClosedRange<Double> {
        (crowdX - crowdHalfWidth)...(crowdX + crowdHalfWidth)
    }

    public var isFinished: Bool {
        state == .won || state == .lost
    }

    public func enemyCount(_ id: Int) -> Int {
        enemyCounts[id] ?? 0
    }

    public func start() {
        guard state == .ready else { return }
        state = .running
    }

    @discardableResult
    public func update(dt: Double) -> [SimEvent] {
        guard state == .running || state == .fighting, dt > 0 else { return [] }
        var events: [SimEvent] = []
        elapsed += dt

        steer(dt: dt)

        if state == .running {
            advance(dt: dt, events: &events)
        }
        if state == .fighting {
            fight(dt: dt, events: &events)
        }
        if state == .running || state == .fighting {
            updateHeroes(dt: dt, events: &events)
        }
        return events
    }

    // MARK: - Internals

    private func steer(dt: Double) {
        let limit = 1 - crowdHalfWidth
        let goal = clamp(targetX, -limit, limit)
        let delta = goal - crowdX
        let step = lateralSpeed * dt
        if abs(delta) <= step {
            crowdX = goal
        } else {
            crowdX += delta > 0 ? step : -step
        }
    }

    private func advance(dt: Double, events: inout [SimEvent]) {
        let previousS = crowdS
        crowdS += forwardSpeed * dt

        // Gates are triggered the moment the crowd centre crosses their line.
        for gate in level.gates where !passedGateIDs.contains(gate.id) {
            guard gate.s > previousS, gate.s <= crowdS else { continue }
            let inLane: Bool
            switch gate.lane {
            case .left: inLane = crowdX < 0
            case .right: inLane = crowdX >= 0
            case .full: inLane = true
            }
            guard inLane else { continue }
            passedGateIDs.insert(gate.id)
            let before = crowdCount
            crowdCount = gate.op.apply(to: before)
            events.append(.gatePassed(gateID: gate.id, op: gate.op, before: before, after: crowdCount))
            if crowdCount <= 0 {
                lose(events: &events)
                return
            }
        }

        // Enemies: engage the first live formation we are about to run into.
        let crowd = crowdRange
        for enemy in level.enemies where (enemyCounts[enemy.id] ?? 0) > 0 {
            let gap = enemy.s - crowdS
            guard gap <= engageDistance, gap > -engageDistance else { continue }
            guard rangesOverlap(enemy.range, crowd) else { continue }
            state = .fighting
            engagedEnemyID = enemy.id
            tradeAccumulator = 0
            crowdS = min(crowdS, enemy.s - engageDistance * 0.6)
            events.append(.battleStarted(enemyID: enemy.id))
            return
        }

        if crowdS >= level.length {
            win(events: &events)
        }
    }

    private func fight(dt: Double, events: inout [SimEvent]) {
        guard let enemyID = engagedEnemyID else {
            state = .running
            return
        }
        tradeAccumulator += dt
        while tradeAccumulator >= tradeInterval, state == .fighting {
            tradeAccumulator -= tradeInterval
            let enemyLeft = enemyCounts[enemyID] ?? 0
            if enemyLeft <= 0 {
                resolveEnemyDefeated(enemyID, events: &events)
                break
            }
            // One-for-one trades, batched so big battles stay snappy.
            let trade = max(1, min(crowdCount, enemyLeft) / 12)
            let crowdLost = min(trade, crowdCount)
            let enemyLost = min(trade, enemyLeft)
            crowdCount -= crowdLost
            enemyCounts[enemyID] = enemyLeft - enemyLost
            events.append(.unitsTraded(enemyID: enemyID, crowdLost: crowdLost, enemyLost: enemyLost))

            if crowdCount <= 0 {
                lose(events: &events)
                return
            }
            if enemyLeft - enemyLost <= 0 {
                resolveEnemyDefeated(enemyID, events: &events)
            }
        }
    }

    private func updateHeroes(dt: Double, events: inout [SimEvent]) {
        for hero in level.heroes {
            // Heroes only act while the crowd is nearby, so distant fights stay untouched.
            guard abs(hero.s - crowdS) <= hero.range * Defaults.heroActivationFactor else { continue }
            var cooldown = (heroCooldowns[hero.id] ?? 0) - dt
            if cooldown <= 0 {
                if let target = nearestLiveEnemy(to: hero) {
                    let left = enemyCounts[target.id] ?? 0
                    let damage = min(hero.damage, left)
                    enemyCounts[target.id] = left - damage
                    events.append(.heroFired(heroID: hero.id, enemyID: target.id, damage: damage))
                    if left - damage <= 0 {
                        resolveEnemyDefeated(target.id, events: &events)
                    }
                    cooldown = hero.fireInterval
                } else {
                    cooldown = 0
                }
            }
            heroCooldowns[hero.id] = cooldown
            if state == .won || state == .lost { return }
        }
    }

    private func nearestLiveEnemy(to hero: HeroSpec) -> EnemyGroupSpec? {
        var best: EnemyGroupSpec?
        var bestDistance = Double.greatestFiniteMagnitude
        for enemy in level.enemies where (enemyCounts[enemy.id] ?? 0) > 0 {
            let d = abs(enemy.s - hero.s)
            guard d <= hero.range else { continue }
            if d < bestDistance {
                bestDistance = d
                best = enemy
            }
        }
        return best
    }

    private func resolveEnemyDefeated(_ enemyID: Int, events: inout [SimEvent]) {
        enemyCounts[enemyID] = 0
        enemiesDefeated += 1
        events.append(.enemyDefeated(enemyID: enemyID))
        if engagedEnemyID == enemyID {
            engagedEnemyID = nil
            if state == .fighting {
                state = .running
            }
        }
        if let enemy = level.enemies.first(where: { $0.id == enemyID }), enemy.isBoss {
            win(events: &events)
        }
    }

    private func win(events: inout [SimEvent]) {
        guard state != .won, state != .lost else { return }
        state = .won
        engagedEnemyID = nil
        events.append(.won(survivors: crowdCount))
    }

    private func lose(events: inout [SimEvent]) {
        guard state != .won, state != .lost else { return }
        state = .lost
        engagedEnemyID = nil
        crowdCount = 0
        events.append(.lost)
    }
}
