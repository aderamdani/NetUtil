import XCTest
@testable import NetUtil

final class WiFiChartAccessibilityTests: XCTestCase {
    func testRssiSummaryDescribesAxes() {
        let s = WiFiInspectorView.rssiChartSummary(count: 30, minRssi: -82, maxRssi: -54, avgRssi: -63)
        XCTAssertTrue(s.contains("X axis"))
        XCTAssertTrue(s.contains("Y axis"))
        XCTAssertTrue(s.contains("30 samples"))
        XCTAssertTrue(s.contains("dBm"))
    }

    func testRssiSummaryHandlesEmpty() {
        let s = WiFiInspectorView.rssiChartSummary(count: 0, minRssi: 0, maxRssi: 0, avgRssi: 0)
        XCTAssertTrue(s.contains("No signal samples"))
    }
}
