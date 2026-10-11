import XCTest
@testable import Kingshot

final class GateOpTests: XCTestCase {
    func testOperationsApply() {
        XCTAssertEqual(GateOp.add(20).apply(to: 10), 30)
        XCTAssertEqual(GateOp.multiply(2).apply(to: 10), 20)
        XCTAssertEqual(GateOp.subtract(15).apply(to: 10), 0)
        XCTAssertEqual(GateOp.divide(2).apply(to: 11), 5)
        XCTAssertEqual(GateOp.divide(0).apply(to: 11), 11)
    }

    func testLabels() {
        XCTAssertEqual(GateOp.add(20).label, "+20")
        XCTAssertEqual(GateOp.multiply(3).label, "x3")
        XCTAssertEqual(GateOp.subtract(5).label, "-5")
        XCTAssertEqual(GateOp.divide(2).label, "÷2")
    }

    func testPolarity() {
        XCTAssertTrue(GateOp.add(1).isPositive)
        XCTAssertTrue(GateOp.multiply(2).isPositive)
        XCTAssertFalse(GateOp.subtract(1).isPositive)
        XCTAssertFalse(GateOp.divide(2).isPositive)
    }
}
