import XCTest
@testable import NetUtil

final class PingChartAccessibilityTests: XCTestCase {
    func testSummaryDescribesAxesCountAndStats() {
        let s = PingLatencyChartView.pingChartSummary(
            count: 100, timeouts: 3, minMs: 8.0, avgMs: 24.5, maxMs: 120.0, top: 150)
        XCTAssertTrue(s.contains("X axis"))
        XCTAssertTrue(s.contains("Y axis"))
        XCTAssertTrue(s.contains("100 pings"))
        XCTAssertTrue(s.contains("3 timed out"))
        XCTAssertTrue(s.contains("milliseconds"))
    }

    func testSummaryHandlesEmpty() {
        let s = PingLatencyChartView.pingChartSummary(
            count: 0, timeouts: 0, minMs: 0, avgMs: 0, maxMs: 0, top: 50)
        XCTAssertTrue(s.contains("No ping data"))
    }
}
