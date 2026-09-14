import XCTest
@testable import NetUtil

final class RouteChangeTests: XCTestCase {
    func testChangeDetected() {
        let prev: [String?] = ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
        let curr: [String?] = ["10.0.0.1", "10.0.0.9", "10.0.0.3"]
        let diff = TracerouteViewModel.changedHopNumbers(previous: prev, current: curr)
        XCTAssertEqual(diff?.changed, [2])
        XCTAssertEqual(diff?.previousCount, 3)
        XCTAssertEqual(diff?.currentCount, 3)
    }

    func testNoChangeReturnsEmpty() {
        let path: [String?] = ["10.0.0.1", "10.0.0.2"]
        let diff = TracerouteViewModel.changedHopNumbers(previous: path, current: path)
        XCTAssertEqual(diff?.changed, [])
    }

    func testLengthChangeFlagsExtraHop() {
        let prev: [String?] = ["10.0.0.1", "10.0.0.2"]
        let curr: [String?] = ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
        let diff = TracerouteViewModel.changedHopNumbers(previous: prev, current: curr)
        XCTAssertEqual(diff?.changed, [3])
        XCTAssertEqual(diff?.currentCount, 3)
    }

    func testNilWhenUnresolved() {
        XCTAssertNil(TracerouteViewModel.changedHopNumbers(previous: [nil, nil], current: [nil, nil]))
        XCTAssertNil(TracerouteViewModel.changedHopNumbers(previous: ["1.1.1.1"], current: [nil]))
    }
}
