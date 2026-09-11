import XCTest
@testable import NetUtil

/// Thin invariant tests for BandwidthMonitor. Ticks are driven by the
/// monitor itself (one synchronous tick per start()); no real timers.
@MainActor
final class BandwidthMonitorTests: XCTestCase {

    func testFreshMonitorIsEmpty() {
        let monitor = BandwidthMonitor()
        XCTAssertTrue(monitor.totalHistory.isEmpty)
        XCTAssertTrue(monitor.history.isEmpty)
        XCTAssertEqual(monitor.totalRxBps, 0)
        XCTAssertEqual(monitor.totalTxBps, 0)
        XCTAssertEqual(monitor.peakRx, 0)
        XCTAssertEqual(monitor.peakTx, 0)
        XCTAssertFalse(monitor.hasTraffic("en0"))
    }

    func testStartStopKeepsHistoryInvariants() {
        let monitor = BandwidthMonitor()
        monitor.start()
        monitor.stop()

        // Capacity caps hold after ticking.
        XCTAssertLessThanOrEqual(monitor.totalHistory.count, 600)
        for samples in monitor.history.values {
            XCTAssertLessThanOrEqual(samples.count, 60)
            // Oldest → newest order.
            let times = samples.map(\.timestamp)
            XCTAssertEqual(times, times.sorted())
        }

        // Current rates always agree with the newest sample.
        XCTAssertEqual(monitor.totalRxBps, monitor.totalHistory.last?.rxBps ?? 0)
        XCTAssertEqual(monitor.totalTxBps, monitor.totalHistory.last?.txBps ?? 0)
    }
}
