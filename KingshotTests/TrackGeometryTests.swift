import XCTest
@testable import Kingshot

final class TrackGeometryTests: XCTestCase {
    func testTrackIsLongEnoughForLevel() {
        let track = TrackGeometry(seed: 42, requiredLength: 150)
        XCTAssertGreaterThanOrEqual(track.usableLength, 150)
    }

    func testTangentsAreUnitLength() {
        let track = TrackGeometry(seed: 7, requiredLength: 120)
        for s in stride(from: -5.0, through: 120.0, by: 2.5) {
            XCTAssertEqual(track.tangent(atS: s).length, 1, accuracy: 1e-6, "tangent at s=\(s)")
        }
    }

    func testPathKeepsClimbing() {
        // The road always heads roughly "up" the map, so y must increase with s.
        let track = TrackGeometry(seed: 99, requiredLength: 200)
        var lastY = track.position(atS: 0).y
        for s in stride(from: 1.0, through: 200.0, by: 1.0) {
            let y = track.position(atS: s).y
            XCTAssertGreaterThan(y, lastY - 1e-6, "y went backwards at s=\(s)")
            lastY = y
        }
    }

    func testLateralOffsetIsPerpendicularAndScaled() {
        let track = TrackGeometry(seed: 3, requiredLength: 100, halfWidth: 3)
        let s = 37.0
        let center = track.position(atS: s)
        let right = track.point(s: s, x: 1)
        let left = track.point(s: s, x: -1)
        XCTAssertEqual((right - center).length, 3, accuracy: 1e-6)
        XCTAssertEqual((left - center).length, 3, accuracy: 1e-6)
        let tangent = track.tangent(atS: s)
        let dot = (right - center).x * tangent.x + (right - center).y * tangent.y
        XCTAssertEqual(dot, 0, accuracy: 1e-6)
    }

    func testCenterlineDistanceIsZeroOnTheRoad() {
        let track = TrackGeometry(seed: 11, requiredLength: 100)
        let p = track.position(atS: 50)
        XCTAssertLessThan(track.distanceToCenterline(p), 0.5)
        let far = p + Vec2(40, 0)
        XCTAssertGreaterThan(track.distanceToCenterline(far), 10)
    }

    func testDeterministic() {
        let a = TrackGeometry(seed: 5, requiredLength: 80)
        let b = TrackGeometry(seed: 5, requiredLength: 80)
        XCTAssertEqual(a.controlPoints, b.controlPoints)
    }
}
