import Foundation

/// Builds a deterministic level from its level number.
///
/// The generator walks along the track dropping "segments": gate pairs, enemy formations,
/// hero-covered ambushes and single buff gates. After every segment it replays the level so
/// far with `GreedyPilot` to learn the headcount a reasonable player really has there, and
/// sizes the next obstacle (and finally the boss) from that measurement. That keeps every
/// level beatable by sensible play while a passive run usually fails.
public enum LevelGenerator {
    public static let heroRange = 8.0
    public static let heroFireInterval = 0.45
    /// Along-track distance from a hero's pedestal to the formation it covers.
    public static let heroAmbushGap = 6.0

    public static func startCount(for level: Int) -> Int {
        min(60, 10 + 2 * (max(1, level) - 1))
    }

    public static func makeLevel(_ level: Int) -> LevelSpec {
        let lvl = max(1, level)
        let seed = UInt64(lvl) &* 0x9E37_79B9_7F4A_7C15 &+ 0x5EED_0000_0000_0001
        var rng = SplitMix64(seed: seed)

        let length = 80.0 + 8.0 * Double(min(lvl, 25))
        let start = startCount(for: lvl)
        let cap = 60.0 + 30.0 * Double(lvl)          // soft ceiling on the headcount
        let track = TrackGeometry(seed: seed, requiredLength: length)
        let pilot = GreedyPilot()

        var gates: [GateSpec] = []
        var enemies: [EnemyGroupSpec] = []
        var heroes: [HeroSpec] = []
        var nextID = 1
        func takeID() -> Int {
            defer { nextID += 1 }
            return nextID
        }

        /// Headcount a greedy player has after everything placed so far.
        func measure(upTo end: Double) -> Int {
            let partial = LevelSpec(level: lvl, seed: seed, length: end, startCount: start,
                                    gates: gates, enemies: enemies, heroes: heroes, track: track)
            return pilot.playThrough(partial).survivors
        }

        func buff(_ headcount: Double, _ low: Double, _ high: Double) -> GateOp {
            if headcount * 2 <= cap, Double.random(in: 0..<1, using: &rng) < 0.5 {
                let triple = lvl >= 6 && headcount * 3 <= cap && Double.random(in: 0..<1, using: &rng) < 0.25
                return .multiply(triple ? 3 : 2)
            }
            return .add(roundTo5(max(5, min(headcount, cap) * Double.random(in: low...high, using: &rng))))
        }

        var headcount = Double(start)
        var s = 16.0
        var segment = 0

        while s < length - 22 {
            let roll = segment == 0 ? 0.0 : Double.random(in: 0..<1, using: &rng)
            let snapshot = (gates, enemies, heroes, s)

            if roll < 0.42 {
                // --- Gate pair: choose between two lanes ---
                var left: GateOp
                var right: GateOp
                let flavour = segment == 0 ? 0.0 : Double.random(in: 0..<1, using: &rng)
                if flavour < 0.55 {
                    // Two buffs of differing quality.
                    left = .add(roundTo5(max(5, min(headcount, cap) * Double.random(in: 0.3...0.6, using: &rng))))
                    right = buff(headcount, 0.7, 1.1)
                } else {
                    // One buff, one trap.
                    let trap: GateOp = Double.random(in: 0..<1, using: &rng) < 0.5
                        ? .subtract(roundTo5(headcount * 0.5))
                        : .divide(2)
                    left = buff(headcount, 0.4, 0.9)
                    right = trap
                }
                if Bool.random(using: &rng) {
                    swap(&left, &right)
                }
                gates.append(GateSpec(id: takeID(), s: s, lane: .left, op: left))
                gates.append(GateSpec(id: takeID(), s: s, lane: .right, op: right))
            } else if roll < 0.72 {
                // --- Enemy formation, full width or in one lane so it can be dodged ---
                let count = max(3, Int(headcount * Double.random(in: 0.3...0.6, using: &rng)))
                let full = Double.random(in: 0..<1, using: &rng) < 0.35
                let x = full ? 0.0 : (Bool.random(using: &rng) ? -0.5 : 0.5)
                enemies.append(EnemyGroupSpec(id: takeID(), s: s, x: x, halfWidth: full ? 1.0 : 0.5, count: count))
            } else if roll < 0.88 {
                // --- Hero on a pedestal covering an ambush ---
                s += 2
                let side: Double = Bool.random(using: &rng) ? -1 : 1
                let damage = 2 + lvl / 3
                heroes.append(HeroSpec(id: takeID(), s: s, side: side, range: heroRange,
                                       damage: damage, fireInterval: heroFireInterval))
                // The formation is sized so that, after the hero's volleys, roughly a third to
                // a half of the player's army is needed to finish it off.
                let contact = max(4, Int(headcount * Double.random(in: 0.35...0.6, using: &rng)))
                enemies.append(EnemyGroupSpec(id: takeID(), s: s + heroAmbushGap, x: 0, halfWidth: 1.0,
                                              count: contact + expectedHeroKills(damage: damage)))
                s += heroAmbushGap
            } else {
                // --- Single full-width buff gate ---
                gates.append(GateSpec(id: takeID(), s: s, lane: .full, op: buff(headcount, 0.4, 0.8)))
            }

            headcount = Double(measure(upTo: s + 8))
            if headcount <= 0 {
                // The segment turned out lethal for a sensible player: swap it for a breather.
                (gates, enemies, heroes, s) = snapshot
                gates.append(GateSpec(id: takeID(), s: s, lane: .full, op: .add(recoveryBonus(lvl))))
                headcount = Double(measure(upTo: s + 8))
            }
            // Never let the army limp on; hand out recovery gates until it is healthy again.
            var recoveries = 0
            while headcount < 15 && recoveries < 3 {
                s += 7
                gates.append(GateSpec(id: takeID(), s: s, lane: .full, op: .add(recoveryBonus(lvl))))
                headcount = Double(measure(upTo: s + 8))
                recoveries += 1
            }

            s += Double.random(in: 9...12, using: &rng)
            segment += 1
        }

        // Make sure there is something to fight the boss with.
        var finalRecoveries = 0
        while headcount < 20 && finalRecoveries < 3 {
            gates.append(GateSpec(id: takeID(), s: s, lane: .full, op: .add(recoveryBonus(lvl))))
            headcount = Double(measure(upTo: s + 8))
            s += 7
            finalRecoveries += 1
        }

        // --- Boss at the end of the road: 60–85 % of what a greedy player brings ---
        let bossCount = max(5, Int(headcount * Double.random(in: 0.6...0.85, using: &rng)))
        enemies.append(EnemyGroupSpec(id: takeID(), s: length - 8, x: 0, halfWidth: 1.0,
                                      count: bossCount, isBoss: true))

        return LevelSpec(level: lvl, seed: seed, length: length, startCount: start,
                         gates: gates, enemies: enemies, heroes: heroes, track: track)
    }

    /// Units a hero removes from its ambush formation before and during the melee, given the
    /// simulation's speeds. Used only to size the formation; the measurement pass corrects
    /// any residual error.
    static func expectedHeroKills(damage: Int) -> Int {
        typealias D = GameSimulation.Defaults
        let window = (heroRange * D.heroActivationFactor + heroAmbushGap - D.engageDistance) / D.forwardSpeed
        let shots = Int((window - heroFireInterval * 0.5) / heroFireInterval) + 2
        return max(0, shots) * damage
    }

    static func recoveryBonus(_ level: Int) -> Int {
        roundTo5(12 + Double(level) * 3)
    }

    static func roundTo5(_ value: Double) -> Int {
        max(5, Int((value / 5).rounded()) * 5)
    }
}
