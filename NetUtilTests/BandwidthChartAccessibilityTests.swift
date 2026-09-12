import XCTest
@testable import NetUtil

final class BandwidthChartAccessibilityTests: XCTestCase {
    func testAggregateSummaryDescribesAxes() {
        let s = BandwidthView.aggregateChartSummary(peak: "5 Mbps", top: "10 Mbps", sampleCount: 60)
        XCTAssertTrue(s.contains("X axis"))
        XCTAssertTrue(s.contains("Y axis"))
        XCTAssertTrue(s.contains("60 samples"))
    }

    func testAggregateSummaryHandlesEmpty() {
        let s = BandwidthView.aggregateChartSummary(peak: "0 bps", top: "0 bps", sampleCount: 0)
        XCTAssertTrue(s.contains("No throughput"))
    }
}
