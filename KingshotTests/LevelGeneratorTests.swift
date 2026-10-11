import XCTest
@testable import Kingshot

final class LevelGeneratorTests: XCTestCase {
    func testDeterministic() {
        let a = LevelGenerator.makeLevel(4)
        let b = LevelGenerator.makeLevel(4)
        XCTAssertEqual(a.gates, b.gates)
        XCTAssertEqual(a.enemies, b.enemies)
        XCTAssertEqual(a.heroes, b.heroes)
    }

    func testEveryLevelHasOneFullWidthBossBeforeTheEnd() {
        for level in 1...40 {
            let spec = LevelGenerator.makeLevel(level)
            let bosses = spec.enemies.filter { $0.isBoss }
            XCTAssertEqual(bosses.count, 1, "level \(level)")
            guard let boss = bosses.first else { continue }
            XCTAssertEqual(boss.halfWidth, 1.0, "level \(level)")
            XCTAssertEqual(boss.x, 0, "level \(level)")
            XCTAssertLessThan(boss.s, spec.length, "level \(level)")
            XCTAssertGreaterThan(boss.s, spec.length - 12, "level \(level)")
        }
    }

    func testEntitiesLieOnTheTrack() {
        for level in 1...40 {
            let spec = LevelGenerator.makeLevel(level)
            XCTAssertGreaterThanOrEqual(spec.track.usableLength, spec.length, "level \(level)")
            for gate in spec.gates {
                XCTAssertGreaterThan(gate.s, 0, "level \(level)")
                XCTAssertLessThan(gate.s, spec.length, "level \(level)")
            }
            for enemy in spec.enemies {
                XCTAssertGreaterThan(enemy.s, 0, "level \(level)")
                XCTAssertLessThan(enemy.s, spec.length, "level \(level)")
                XCTAssertGreaterThanOrEqual(enemy.range.lowerBound, -1.0 - 1e-9, "level \(level)")
                XCTAssertLessThanOrEqual(enemy.range.upperBound, 1.0 + 1e-9, "level \(level)")
                XCTAssertGreaterThan(enemy.count, 0, "level \(level)")
            }
            for hero in spec.heroes {
                XCTAssertGreaterThan(hero.s, 0, "level \(level)")
                XCTAssertLessThan(hero.s, spec.length, "level \(level)")
                XCTAssertTrue(hero.side == -1 || hero.side == 1, "level \(level)")
            }
        }
    }

    func testFirstChoiceIsTwoBuffGates() {
        for level in 1...40 {
            let spec = LevelGenerator.makeLevel(level)
            let firstS = spec.gates.map(\.s).min() ?? 0
            let opening = spec.gates.filter { $0.s == firstS }
            XCTAssertEqual(opening.count, 2, "level \(level)")
            XCTAssertTrue(opening.allSatisfy { $0.op.isPositive }, "level \(level)")
            XCTAssertEqual(Set(opening.map { $0.lane == .left }).count, 2, "level \(level)")
            // The opening gates must come before any enemy.
            let firstEnemyS = spec.enemies.map(\.s).min() ?? .infinity
            XCTAssertLessThan(firstS, firstEnemyS, "level \(level)")
        }
    }

    func testGatePairsShareDistanceAndOppositeLanes() {
        let spec = LevelGenerator.makeLevel(9)
        let grouped = Dictionary(grouping: spec.gates.filter { $0.lane != .full }, by: \.s)
        for (s, gates) in grouped {
            XCTAssertEqual(gates.count, 2, "pair at s=\(s)")
            XCTAssertEqual(Set(gates.map { $0.lane == .left }).count, 2, "pair at s=\(s)")
        }
    }

    func testDifficultyGrowsWithLevel() {
        let early = LevelGenerator.makeLevel(1)
        let late = LevelGenerator.makeLevel(30)
        XCTAssertGreaterThan(late.length, early.length)
        XCTAssertGreaterThan(late.startCount, early.startCount)
        XCTAssertGreaterThan(late.boss?.count ?? 0, early.boss?.count ?? 0)
    }

    func testBossIsSizedAgainstAGreedyRun() {
        // The boss must be beatable by greedy play but still cost a real share of the army.
        for level in 1...25 {
            let spec = LevelGenerator.makeLevel(level)
            let result = GreedyPilot().playThrough(spec)
            XCTAssertEqual(result.state, .won, "level \(level)")
            let boss = spec.boss?.count ?? 0
            let arrival = result.survivors + boss
            XCTAssertGreaterThanOrEqual(Double(boss), Double(arrival) * 0.5, "level \(level) boss too small")
            XCTAssertLessThan(boss, arrival, "level \(level) boss too big")
        }
    }

    func testPassivePlayIsNotEnoughOnMostLevels() {
        // Running straight down the middle (taking whichever right-hand gate comes) should fail
        // more often than not; the game is about choosing lanes.
        var losses = 0
        for level in 1...25 {
            let sim = GameSimulation(level: LevelGenerator.makeLevel(level))
            sim.start()
            var ticks = 0
            while !sim.isFinished && ticks < 60_000 {
                sim.update(dt: 1.0 / 60.0)
                ticks += 1
            }
            if sim.state == .lost { losses += 1 }
        }
        XCTAssertGreaterThan(losses, 10)
    }

    func testGenerationIsFastEnoughForLevelLoad() {
        measure {
            _ = LevelGenerator.makeLevel(25)
        }
    }
}
