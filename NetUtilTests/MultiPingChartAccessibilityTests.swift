import XCTest
@testable import NetUtil

final class MultiPingChartAccessibilityTests: XCTestCase {
    func testSlotSummaryDescribesAxes() {
        let s = MultiPingSlotRow.slotChartSummary(host: "8.8.8.8", count: 50, timeouts: 2, minMs: 9.0, avgMs: 21.0, maxMs: 88.0, top: 100)
        XCTAssertTrue(s.contains("8.8.8.8"))
        XCTAssertTrue(s.contains("X axis"))
        XCTAssertTrue(s.contains("Y axis"))
        XCTAssertTrue(s.contains("50 pings"))
        XCTAssertTrue(s.contains("2 timed out"))
    }

    func testSlotSummaryHandlesEmpty() {
        let s = MultiPingSlotRow.slotChartSummary(host: "1.1.1.1", count: 0, timeouts: 0, minMs: 0, avgMs: 0, maxMs: 0, top: 10)
        XCTAssertTrue(s.contains("No ping data"))
    }
}
