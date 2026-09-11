import XCTest
@testable import NetUtil

/// Anti-fusion tests for VoiceOver/MoodBar strings, via the pure message
/// builders on each view (StatisticsMessagesTests pattern). No views
/// rendered. Representative cases: 0/1/many, loss 0/>0, running/idle.
@MainActor
final class ToolMessagesTests: XCTestCase {

    // MARK: - MultiPing mood

    func testMultiPingEmpty() {
        XCTAssertEqual(MultiPingView.moodMessage(active: 0, total: 0, avgLoss: 0), "No hosts added")
    }

    func testMultiPingStoppedSingularPlural() {
        XCTAssertEqual(
            MultiPingView.moodMessage(active: 0, total: 1, avgLoss: 0),
            "Monitoring stopped — 1 host configured"
        )
        XCTAssertEqual(
            MultiPingView.moodMessage(active: 0, total: 3, avgLoss: 0),
            "Monitoring stopped — 3 hosts configured"
        )
    }

    func testMultiPingActiveCleanAndLossy() {
        XCTAssertEqual(
            MultiPingView.moodMessage(active: 2, total: 3, avgLoss: 0),
            "Active: 2/3 — All hosts reachable"
        )
        XCTAssertEqual(
            MultiPingView.moodMessage(active: 2, total: 3, avgLoss: 5.27),
            "Active: 2/3 — Avg loss: 5.3%"
        )
    }

    func testMultiPingNoFusedTokens() {
        for (active, total, loss) in [(0, 1, 0.0), (0, 5, 0.0), (3, 5, 0.0), (3, 5, 12.3)] {
            let msg = MultiPingView.moodMessage(active: active, total: total, avgLoss: loss)
            XCTAssertFalse(msg.contains("hostconfigured"), msg)
            XCTAssertFalse(msg.contains("—Avg"), msg)
            XCTAssertFalse(msg.contains("/5—"), msg)
            XCTAssertFalse(msg.contains("  "), msg)
            XCTAssertTrue(msg.contains(" — "), msg)
        }
    }

    // MARK: - Traceroute mood + spoken latency

    func testTracerouteTracingMessage() {
        XCTAssertEqual(
            TracerouteView.tracingMessage(host: "example.com", round: 1, hopCount: 3),
            "Tracing example.com — round 2, 3 hops"
        )
    }

    func testTraceroutePathMessages() {
        XCTAssertEqual(
            TracerouteView.pathLossMessage(loss: 12.3, hopCount: 3, avg: "45.6 ms"),
            "12.3% loss on path — 3 hops, avg 45.6 ms"
        )
        XCTAssertEqual(
            TracerouteView.pathCleanMessage(hopCount: 1, avg: "10.0 ms"),
            "1 hops — path avg 10.0 ms"
        )
        XCTAssertEqual(
            TracerouteView.pathCleanMessage(hopCount: 0, avg: "—"),
            "0 hops — path avg —"
        )
    }

    func testTracerouteSpokenMilliseconds() {
        XCTAssertEqual(TracerouteView.spokenMilliseconds(45.6), "45 milliseconds")
        XCTAssertEqual(TracerouteView.spokenMilliseconds(0), "0 milliseconds")
    }

    func testTracerouteNoFusedTokens() {
        let tracing = TracerouteView.tracingMessage(host: "example.com", round: 0, hopCount: 12)
        XCTAssertFalse(tracing.contains("12hops"), tracing)
        XCTAssertFalse(tracing.contains("—round"), tracing)
        let loss = TracerouteView.pathLossMessage(loss: 5, hopCount: 12, avg: "1.0 ms")
        XCTAssertFalse(loss.contains("12hops"), loss)
    }

    // MARK: - Ping spoken latency + link types

    func testPingSpokenMilliseconds() {
        XCTAssertEqual(PingView.spokenMilliseconds(45.6), "45 milliseconds")
        XCTAssertEqual(PingView.spokenMilliseconds(0.4), "0 milliseconds")
        for value in [0.0, 1.2, 45.6, 999.9] {
            let spoken = PingView.spokenMilliseconds(value)
            XCTAssertTrue(spoken.hasSuffix(" milliseconds"), spoken)
            XCTAssertFalse(spoken.contains("  "), spoken)
        }
    }

    func testPingLinkTypeStrings() {
        XCTAssertEqual(
            PingView.linkTypeAccessibilityLabel(title: "Fiber", typical: "10-50 ms"),
            "Fiber, typical latency 10-50 ms"
        )
        XCTAssertEqual(
            PingView.linkTypeMatchText(prefix: "", title: "Fiber", typical: "10-50 ms"),
            "Fiber · typical 10-50 ms"
        )
        XCTAssertEqual(
            PingView.linkTypeMatchText(prefix: "Likely match: ", title: "Fiber", typical: "10-50 ms"),
            "Likely match: Fiber · typical 10-50 ms"
        )
        XCTAssertEqual(
            PingView.linkTypeDetailsLabel(title: "Fiber", typical: "10-50 ms", blurb: "Fast."),
            "Link type details. Fiber, typical latency 10-50 ms. Fast."
        )
    }

    func testPingWifiSummary() {
        XCTAssertEqual(PingView.signalStrengthText(rssi: -55), "-55 dBm")
        XCTAssertEqual(
            PingView.wifiSummary(parts: ["HomeNet", "-55 dBm"]),
            "Wi-Fi · HomeNet · -55 dBm"
        )
        XCTAssertEqual(PingView.wifiSummary(parts: ["HomeNet"]), "Wi-Fi · HomeNet")
        let summary = PingView.wifiSummary(parts: ["HomeNet", "-55 dBm"])
        XCTAssertFalse(summary.contains("-55dBm"), summary)
        XCTAssertFalse(summary.contains("·typical"), summary)
        XCTAssertTrue(summary.contains(" · "))
    }

    // MARK: - SSL copy status

    func testSSLExpiryCopyStatus() {
        XCTAssertEqual(SSLInspectorView.expiryCopyStatus(days: nil), "Unknown")
        XCTAssertEqual(SSLInspectorView.expiryCopyStatus(days: -5), "Expired 5 days ago")
        XCTAssertEqual(SSLInspectorView.expiryCopyStatus(days: -1), "Expired 1 day ago")
        XCTAssertEqual(SSLInspectorView.expiryCopyStatus(days: 0), "Valid, 0 days remaining")
        XCTAssertEqual(SSLInspectorView.expiryCopyStatus(days: 1), "Valid, 1 day remaining")
        XCTAssertEqual(SSLInspectorView.expiryCopyStatus(days: 30), "Valid, 30 days remaining")
    }

    func testSSLExpiryCopyStatusNoFusedTokens() {
        for days in [-30, -1, 0, 1, 30] {
            let status = SSLInspectorView.expiryCopyStatus(days: days)
            XCTAssertFalse(status.contains("5days") || status.contains("1day ") || status.contains("0days"), status)
            XCTAssertFalse(status.contains("  "), status)
        }
    }
}
