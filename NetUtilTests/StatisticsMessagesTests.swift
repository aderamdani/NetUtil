import XCTest
@testable import NetUtil

/// Pure message-builder tests for the Statistics summaries. Guards the
/// VoiceOver/display spacing (no fused tokens) and day singular/plural.
/// Synchronous — no views rendered.
@MainActor
final class StatisticsMessagesTests: XCTestCase {

    // MARK: - moodBarMessage

    func testMoodBarExactFormat() {
        XCTAssertEqual(
            StatisticsView.moodBarMessage(todayBytes: "1.2 GB", days: 5),
            "Today: 1.2 GB total — 5 days of history"
        )
    }

    func testMoodBarSingularDay() {
        let msg = StatisticsView.moodBarMessage(todayBytes: "0 B", days: 1)
        XCTAssertEqual(msg, "Today: 0 B total — 1 day of history")
        XCTAssertFalse(msg.contains("days"))
    }

    func testMoodBarZeroAndManyDays() {
        XCTAssertEqual(
            StatisticsView.moodBarMessage(todayBytes: "0 B", days: 0),
            "Today: 0 B total — 0 days of history"
        )
        XCTAssertEqual(
            StatisticsView.moodBarMessage(todayBytes: "3.4 TB", days: 90),
            "Today: 3.4 TB total — 90 days of history"
        )
    }

    func testMoodBarHasNoFusedTokens() {
        for days in [0, 1, 2, 30] {
            let msg = StatisticsView.moodBarMessage(todayBytes: "1.2 GB", days: days)
            XCTAssertFalse(msg.contains("GBtotal"), msg)
            XCTAssertFalse(msg.contains("daysof"), msg)
            XCTAssertFalse(msg.contains("dayof"), msg)
            XCTAssertFalse(msg.contains("  "), msg)
            XCTAssertTrue(msg.contains(" of history"))
        }
    }

    // MARK: - liveSummary

    func testLiveSummaryExactFormat() {
        XCTAssertEqual(
            StatisticsView.liveSummary(peak: "5.0 Mbps", top: "10.0 Mbps", sampleCount: 120),
            "Line chart. Time on the X axis, throughput on the Y axis from 0 to 10.0 Mbps. Peak 5.0 Mbps over 120 samples."
        )
    }

    func testLiveSummaryHasNoFusedTokens() {
        let summary = StatisticsView.liveSummary(peak: "5.0 Mbps", top: "10.0 Mbps", sampleCount: 3)
        XCTAssertTrue(summary.contains("over 3 samples."))
        XCTAssertFalse(summary.contains("over3"), summary)
        XCTAssertFalse(summary.contains("  "), summary)
    }

    // MARK: - dailySummary

    func testDailySummaryExactFormat() {
        XCTAssertEqual(
            StatisticsView.dailySummary(top: "2.0 GB", dayCount: 7),
            "Stacked bar chart. Date on the X axis, bytes on the Y axis from 0 to 2.0 GB. 7 days."
        )
    }

    func testDailySummaryDayCounts() {
        XCTAssertTrue(StatisticsView.dailySummary(top: "1.0 GB", dayCount: 0).hasSuffix("0 days."))
        XCTAssertTrue(StatisticsView.dailySummary(top: "1.0 GB", dayCount: 1).contains(" 1 days."))
        let summary = StatisticsView.dailySummary(top: "1.0 GB", dayCount: 30)
        XCTAssertTrue(summary.contains("30 days."))
        XCTAssertFalse(summary.contains("  "), summary)
    }
}
