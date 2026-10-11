import XCTest
@testable import Kingshot

final class GameSimulationTests: XCTestCase {
    private func makeLevel(gates: [GateSpec] = [], enemies: [EnemyGroupSpec] = [],
                           heroes: [HeroSpec] = [], length: Double = 60, startCount: Int = 10) -> LevelSpec {
        LevelSpec(level: 1, seed: 1, length: length, startCount: startCount,
                  gates: gates, enemies: enemies, heroes: heroes,
                  track: TrackGeometry(seed: 1, requiredLength: length))
    }

    /// Steps the simulation at 60 Hz until it finishes or `maxSeconds` pass.
    @discardableResult
    private func play(_ sim: GameSimulation, maxSeconds: Double = 60) -> [SimEvent] {
        var events: [SimEvent] = []
        var t = 0.0
        while !sim.isFinished && t < maxSeconds {
            events += sim.update(dt: 1.0 / 60.0)
            t += 1.0 / 60.0
        }
        return events
    }

    func testDoesNotMoveBeforeStart() {
        let sim = GameSimulation(level: makeLevel())
        sim.update(dt: 1)
        XCTAssertEqual(sim.crowdS, 0)
        XCTAssertEqual(sim.state, .ready)
    }

    func testReachingTheEndWins() {
        let sim = GameSimulation(level: makeLevel(length: 20))
        sim.start()
        let events = play(sim)
        XCTAssertEqual(sim.state, .won)
        XCTAssertTrue(events.contains(.won(survivors: 10)))
    }

    func testGateInTheCrowdsLaneApplies() {
        let gates = [GateSpec(id: 1, s: 5, lane: .left, op: .add(20)),
                     GateSpec(id: 2, s: 5, lane: .right, op: .multiply(2))]
        let sim = GameSimulation(level: makeLevel(gates: gates, length: 15))
        sim.targetX = 1          // steer hard right
        sim.start()
        let events = play(sim)
        XCTAssertEqual(sim.crowdCount, 20)
        XCTAssertTrue(events.contains(.gatePassed(gateID: 2, op: .multiply(2), before: 10, after: 20)))
        XCTAssertFalse(events.contains { if case .gatePassed(let id, _, _, _) = $0 { return id == 1 } else { return false } })
    }

    func testFullWidthGateAlwaysApplies() {
        let gates = [GateSpec(id: 1, s: 5, lane: .full, op: .add(5))]
        let sim = GameSimulation(level: makeLevel(gates: gates, length: 15))
        sim.targetX = -1
        sim.start()
        play(sim)
        XCTAssertEqual(sim.crowdCount, 15)
    }

    func testTrapGateThatEmptiesTheCrowdLoses() {
        let gates = [GateSpec(id: 1, s: 5, lane: .full, op: .subtract(50))]
        let sim = GameSimulation(level: makeLevel(gates: gates, length: 15))
        sim.start()
        let events = play(sim)
        XCTAssertEqual(sim.state, .lost)
        XCTAssertTrue(events.contains(.lost))
    }

    func testBattleTradesOneForOne() {
        let enemies = [EnemyGroupSpec(id: 1, s: 8, x: 0, halfWidth: 1, count: 4)]
        let sim = GameSimulation(level: makeLevel(enemies: enemies, length: 20))
        sim.start()
        let events = play(sim)
        XCTAssertEqual(sim.state, .won)
        XCTAssertEqual(sim.crowdCount, 6)
        XCTAssertEqual(sim.enemyCount(1), 0)
        XCTAssertTrue(events.contains(.battleStarted(enemyID: 1)))
        XCTAssertTrue(events.contains(.enemyDefeated(enemyID: 1)))
    }

    func testEqualNumbersLoseToTheBoss() {
        let enemies = [EnemyGroupSpec(id: 1, s: 8, x: 0, halfWidth: 1, count: 10, isBoss: true)]
        let sim = GameSimulation(level: makeLevel(enemies: enemies, length: 20))
        sim.start()
        play(sim)
        XCTAssertEqual(sim.state, .lost)
    }

    func testBeatingTheBossWinsImmediately() {
        let enemies = [EnemyGroupSpec(id: 1, s: 8, x: 0, halfWidth: 1, count: 3, isBoss: true)]
        let sim = GameSimulation(level: makeLevel(enemies: enemies, length: 200))
        sim.start()
        let events = play(sim, maxSeconds: 10)
        XCTAssertEqual(sim.state, .won)
        XCTAssertTrue(events.contains(.won(survivors: 7)))
    }

    func testCrowdCanDodgeALaneFormation() {
        let enemies = [EnemyGroupSpec(id: 1, s: 8, x: -0.5, halfWidth: 0.5, count: 50)]
        let sim = GameSimulation(level: makeLevel(enemies: enemies, length: 20))
        sim.targetX = 1
        sim.start()
        play(sim)
        XCTAssertEqual(sim.state, .won)
        XCTAssertEqual(sim.crowdCount, 10)
    }

    func testHeroThinsOutEnemiesBeforeContact() {
        let enemies = [EnemyGroupSpec(id: 1, s: 30, x: 0, halfWidth: 1, count: 30)]
        let heroes = [HeroSpec(id: 2, s: 26, side: 1, range: 14, damage: 5, fireInterval: 0.3)]
        let withHero = GameSimulation(level: makeLevel(enemies: enemies, heroes: heroes, length: 40, startCount: 20))
        withHero.start()
        let events = play(withHero)
        XCTAssertTrue(events.contains { if case .heroFired = $0 { return true } else { return false } })

        let without = GameSimulation(level: makeLevel(enemies: enemies, length: 40, startCount: 20))
        without.start()
        play(without)
        XCTAssertEqual(without.state, .lost)
        XCTAssertGreaterThan(withHero.crowdCount, without.crowdCount)
    }

    func testLateralSteeringIsClampedToTheRoad() {
        let sim = GameSimulation(level: makeLevel(length: 500))
        sim.targetX = 5
        sim.start()
        for _ in 0..<120 { sim.update(dt: 1.0 / 60.0) }
        XCTAssertLessThanOrEqual(sim.crowdX, 1 - sim.crowdHalfWidth + 1e-9)
        sim.targetX = -5
        for _ in 0..<240 { sim.update(dt: 1.0 / 60.0) }
        XCTAssertGreaterThanOrEqual(sim.crowdX, -1 + sim.crowdHalfWidth - 1e-9)
    }

    func testGeneratedLevelsAreWinnableByTakingTheBestGates() {
        let pilot = GreedyPilot()
        for level in 1...25 {
            let result = pilot.playThrough(LevelGenerator.makeLevel(level))
            XCTAssertEqual(result.state, .won, "level \(level) should be winnable with greedy play")
            XCTAssertGreaterThan(result.survivors, 0, "level \(level)")
        }
    }

    func testGreedyPilotPrefersTheBetterGate() {
        let gates = [GateSpec(id: 1, s: 5, lane: .left, op: .add(5)),
                     GateSpec(id: 2, s: 5, lane: .right, op: .multiply(2))]
        let sim = GameSimulation(level: makeLevel(gates: gates, length: 15, startCount: 10))
        GreedyPilot().steer(sim)
        XCTAssertEqual(sim.targetX, Lane.right.center)

        let big = GameSimulation(level: makeLevel(gates: gates, length: 15, startCount: 3))
        GreedyPilot().steer(big)
        XCTAssertEqual(big.targetX, Lane.left.center)   // +5 beats x2 when you only have 3
    }
}
