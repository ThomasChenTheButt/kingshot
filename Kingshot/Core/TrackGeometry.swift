import Foundation

/// A winding path generated from a seed and sampled into an arc-length lookup table.
///
/// The centreline is a Catmull-Rom spline through randomly turned control points that
/// always keep heading roughly "up" (+y), which is how the Kingshot road winds up the map.
public struct TrackGeometry {
    public let controlPoints: [Vec2]
    public let samplePositions: [Vec2]
    public let sampleTangents: [Vec2]
    public let sampleDistances: [Double]
    /// Half of the walkable path width, in track units. Lateral x = ±1 maps to ±halfWidth.
    public let halfWidth: Double
    /// Amount of path that exists before s = 0 so the start of the level is not a hard edge.
    public let leadIn: Double

    public var totalSampledLength: Double {
        sampleDistances.last ?? 0
    }

    /// Length available for the level (excludes the lead-in).
    public var usableLength: Double {
        max(0, totalSampledLength - leadIn)
    }

    public init(seed: UInt64,
                requiredLength: Double,
                halfWidth: Double = 3.0,
                stepLength: Double = 7.0,
                leadIn: Double = 10.0,
                tail: Double = 14.0,
                straightSegments: Int = 2,
                samplesPerSegment: Int = 16) {
        self.halfWidth = halfWidth
        self.leadIn = leadIn

        var rng = SplitMix64(seed: seed ^ 0xC0FF_EE00_1234_5678)
        let needed = leadIn + requiredLength + tail
        let segmentCount = Int((needed / stepLength).rounded(.up)) + 1

        var points: [Vec2] = []
        points.reserveCapacity(segmentCount + 3)
        points.append(Vec2(0, -stepLength))   // phantom start for the spline
        var p = Vec2(0, 0)
        points.append(p)
        let up = Double.pi / 2
        var heading = up
        for i in 0..<segmentCount {
            if i >= straightSegments {
                // Random turn with mild mean reversion so the road keeps climbing the map.
                let bias = (up - heading) * 0.35
                let turn = Double.random(in: -0.55...0.55, using: &rng) + bias
                heading = clamp(heading + turn, up - 1.05, up + 1.05)
            }
            p += Vec2(cos(heading), sin(heading)) * stepLength
            points.append(p)
        }
        // Phantom end point continuing straight on.
        points.append(p + Vec2(cos(heading), sin(heading)) * stepLength)
        controlPoints = points

        var positions: [Vec2] = []
        var tangents: [Vec2] = []
        var distances: [Double] = []
        let segments = points.count - 3
        positions.reserveCapacity(segments * samplesPerSegment + 1)
        tangents.reserveCapacity(segments * samplesPerSegment + 1)
        distances.reserveCapacity(segments * samplesPerSegment + 1)

        var running = 0.0
        for seg in 1...(points.count - 3) {
            let p0 = points[seg - 1], p1 = points[seg], p2 = points[seg + 1], p3 = points[seg + 2]
            let isLast = seg == points.count - 3
            let steps = isLast ? samplesPerSegment + 1 : samplesPerSegment
            for k in 0..<steps {
                let t = Double(k) / Double(samplesPerSegment)
                let t2 = t * t
                let t3 = t2 * t
                let a = p1 * 2
                let b = p2 - p0
                let c = p0 * 2 - p1 * 5 + p2 * 4 - p3
                let d = (p1 - p2) * 3 - p0 + p3
                let pos = (a + b * t + c * t2 + d * t3) * 0.5
                let tan = (b + c * (2 * t) + d * (3 * t2)) * 0.5
                if let last = positions.last {
                    running += (pos - last).length
                }
                positions.append(pos)
                tangents.append(tan.normalized)
                distances.append(running)
            }
        }
        samplePositions = positions
        sampleTangents = tangents
        sampleDistances = distances
    }

    // MARK: Queries

    private func locate(_ s: Double) -> (index: Int, fraction: Double) {
        let total = totalSampledLength
        let d = clamp(s + leadIn, 0, total)
        var lo = 0
        var hi = sampleDistances.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if sampleDistances[mid] <= d { lo = mid } else { hi = mid }
        }
        let span = sampleDistances[hi] - sampleDistances[lo]
        let f = span > 1e-9 ? (d - sampleDistances[lo]) / span : 0
        return (lo, clamp(f, 0, 1))
    }

    /// Centreline position at track distance `s` (s = 0 is where the crowd starts).
    public func position(atS s: Double) -> Vec2 {
        let (i, f) = locate(s)
        let a = samplePositions[i]
        let b = samplePositions[min(i + 1, samplePositions.count - 1)]
        return a + (b - a) * f
    }

    /// Unit tangent (direction of travel) at track distance `s`.
    public func tangent(atS s: Double) -> Vec2 {
        let (i, f) = locate(s)
        let a = sampleTangents[i]
        let b = sampleTangents[min(i + 1, sampleTangents.count - 1)]
        return (a + (b - a) * f).normalized
    }

    /// World position for a track coordinate. `x` is lateral, -1 = left edge, +1 = right edge.
    public func point(s: Double, x: Double) -> Vec2 {
        position(atS: s) + tangent(atS: s).rightPerpendicular * (x * halfWidth)
    }

    /// Distance from an arbitrary world point to the nearest centreline sample.
    public func distanceToCenterline(_ p: Vec2) -> Double {
        var best = Double.greatestFiniteMagnitude
        for q in samplePositions {
            let d = (q - p).length
            if d < best { best = d }
        }
        return best
    }

    /// Axis-aligned bounds of the centreline.
    public var bounds: (min: Vec2, max: Vec2) {
        var lo = Vec2(Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude)
        var hi = Vec2(-Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude)
        for q in samplePositions {
            lo = Vec2(min(lo.x, q.x), min(lo.y, q.y))
            hi = Vec2(max(hi.x, q.x), max(hi.y, q.y))
        }
        return (lo, hi)
    }
}
