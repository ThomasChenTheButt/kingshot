import Foundation

// MARK: - Track coordinates
//
// Everything in the simulation lives in "track space":
//   s  = distance travelled along the path centreline (track units)
//   x  = lateral offset across the path, -1 (left edge) ... +1 (right edge)
//
// The scene converts (s, x) into world points with `TrackGeometry`.

public enum Lane: Equatable {
    case left
    case right
    case full

    /// Lateral interval occupied by this lane.
    public var range: ClosedRange<Double> {
        switch self {
        case .left: return -1.0...0.0
        case .right: return 0.0...1.0
        case .full: return -1.0...1.0
        }
    }

    /// Lateral centre of the lane.
    public var center: Double {
        switch self {
        case .left: return -0.5
        case .right: return 0.5
        case .full: return 0.0
        }
    }

    public var width: Double {
        range.upperBound - range.lowerBound
    }
}

public enum GateOp: Equatable {
    case add(Int)
    case multiply(Int)
    case subtract(Int)
    case divide(Int)

    public var isPositive: Bool {
        switch self {
        case .add, .multiply: return true
        case .subtract, .divide: return false
        }
    }

    public func apply(to count: Int) -> Int {
        switch self {
        case .add(let n): return max(0, count + n)
        case .multiply(let n): return max(0, count * n)
        case .subtract(let n): return max(0, count - n)
        case .divide(let n): return n <= 0 ? count : max(0, count / n)
        }
    }

    public var label: String {
        switch self {
        case .add(let n): return "+\(n)"
        case .multiply(let n): return "x\(n)"
        case .subtract(let n): return "-\(n)"
        case .divide(let n): return "÷\(n)"
        }
    }
}

public struct GateSpec: Identifiable, Equatable {
    public let id: Int
    public let s: Double
    public let lane: Lane
    public let op: GateOp

    public init(id: Int, s: Double, lane: Lane, op: GateOp) {
        self.id = id
        self.s = s
        self.lane = lane
        self.op = op
    }
}

public struct EnemyGroupSpec: Identifiable, Equatable {
    public let id: Int
    public let s: Double
    /// Lateral centre of the formation.
    public let x: Double
    /// Lateral half extent of the formation.
    public let halfWidth: Double
    public let count: Int
    public let isBoss: Bool

    public init(id: Int, s: Double, x: Double, halfWidth: Double, count: Int, isBoss: Bool = false) {
        self.id = id
        self.s = s
        self.x = x
        self.halfWidth = halfWidth
        self.count = count
        self.isBoss = isBoss
    }

    public var range: ClosedRange<Double> {
        (x - halfWidth)...(x + halfWidth)
    }
}

/// A hero standing on a pedestal beside the path. Fires at enemy groups in range.
public struct HeroSpec: Identifiable, Equatable {
    public let id: Int
    public let s: Double
    /// -1 places the pedestal on the left bank, +1 on the right bank.
    public let side: Double
    /// Along-track distance (in both directions) within which enemies can be targeted.
    public let range: Double
    /// Units removed from the target per shot.
    public let damage: Int
    public let fireInterval: Double

    public init(id: Int, s: Double, side: Double, range: Double, damage: Int, fireInterval: Double) {
        self.id = id
        self.s = s
        self.side = side
        self.range = range
        self.damage = damage
        self.fireInterval = fireInterval
    }
}

public struct LevelSpec {
    public let level: Int
    public let seed: UInt64
    /// Track distance at which the level ends (the boss sits shortly before this).
    public let length: Double
    public let startCount: Int
    public let gates: [GateSpec]
    public let enemies: [EnemyGroupSpec]
    public let heroes: [HeroSpec]
    public let track: TrackGeometry

    public init(level: Int, seed: UInt64, length: Double, startCount: Int,
                gates: [GateSpec], enemies: [EnemyGroupSpec], heroes: [HeroSpec], track: TrackGeometry) {
        self.level = level
        self.seed = seed
        self.length = length
        self.startCount = startCount
        self.gates = gates
        self.enemies = enemies
        self.heroes = heroes
        self.track = track
    }

    public var boss: EnemyGroupSpec? {
        enemies.first(where: { $0.isBoss })
    }
}

// MARK: - Small vector helpers

public typealias Vec2 = SIMD2<Double>

extension SIMD2 where Scalar == Double {
    public var length: Double {
        (x * x + y * y).squareRoot()
    }

    public var normalized: SIMD2<Double> {
        let len = length
        return len > 1e-9 ? self / len : SIMD2<Double>(0, 1)
    }

    /// Perpendicular pointing to the right of the direction of travel.
    public var rightPerpendicular: SIMD2<Double> {
        SIMD2<Double>(y, -x)
    }

    public var angle: Double {
        atan2(y, x)
    }
}

@inline(__always)
func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}

@inline(__always)
func rangesOverlap(_ a: ClosedRange<Double>, _ b: ClosedRange<Double>) -> Bool {
    max(a.lowerBound, b.lowerBound) < min(a.upperBound, b.upperBound)
}
