import Foundation

/// A baseline "reasonable player": always steers into the better of the next pair of gates
/// and otherwise runs down the middle of the road, fighting whatever is there.
///
/// `LevelGenerator` uses it to measure the real headcount at each point of a level so that
/// enemy formations and the boss are sized against what a player actually has, and the unit
/// tests use it to prove generated levels are winnable.
public struct GreedyPilot {
    public init() {}

    public func steer(_ sim: GameSimulation) {
        var nextS = Double.greatestFiniteMagnitude
        for gate in sim.level.gates where gate.s > sim.crowdS && !sim.passedGateIDs.contains(gate.id) {
            nextS = min(nextS, gate.s)
        }
        guard nextS < Double.greatestFiniteMagnitude else {
            sim.targetX = 0
            return
        }
        var bestLane: Lane = .full
        var bestOutcome = Int.min
        for gate in sim.level.gates where gate.s == nextS {
            let outcome = gate.op.apply(to: sim.crowdCount)
            if outcome > bestOutcome {
                bestOutcome = outcome
                bestLane = gate.lane
            }
        }
        sim.targetX = bestLane.center
    }

    /// Runs a fresh simulation of `level` to the end under this pilot.
    /// Returns the surviving headcount, or 0 if the pilot lost.
    public func playThrough(_ level: LevelSpec, maxTicks: Int = 60_000) -> (state: SimState, survivors: Int) {
        let sim = GameSimulation(level: level)
        sim.start()
        let dt = 1.0 / GameSimulation.Defaults.tickRate
        var ticks = 0
        while !sim.isFinished && ticks < maxTicks {
            steer(sim)
            sim.update(dt: dt)
            ticks += 1
        }
        return (sim.state, sim.state == .won ? sim.crowdCount : 0)
    }
}
