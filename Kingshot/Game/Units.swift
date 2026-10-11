import CoreGraphics

/// Conversion between simulation track units and SpriteKit points.
enum Units {
    static let pointsPerUnit: CGFloat = 36

    static func point(_ v: Vec2) -> CGPoint {
        CGPoint(x: CGFloat(v.x) * pointsPerUnit, y: CGFloat(v.y) * pointsPerUnit)
    }

    static func vector(_ v: Vec2) -> CGVector {
        CGVector(dx: CGFloat(v.x) * pointsPerUnit, dy: CGFloat(v.y) * pointsPerUnit)
    }

    static func points(_ units: Double) -> CGFloat {
        CGFloat(units) * pointsPerUnit
    }
}

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    var magnitude: CGFloat {
        (x * x + y * y).squareRoot()
    }
}
