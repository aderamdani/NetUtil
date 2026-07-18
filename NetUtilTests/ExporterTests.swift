import XCTest
@testable import NetUtil

final class ExporterTests: XCTestCase {
    
    func testCSVGeneration() {
        let result = PingResult(
            sequence: 1,
            bytes: 64,
            host: "example.com",
            ipAddress: "127.0.0.1",
            ttl: 64,
            rtt: 10.5,
            status: .success
        )
        
        let csv = Exporter.csvString(from: [result])
        XCTAssertTrue(csv.contains("example.com"))
        XCTAssertTrue(csv.contains("10.5"))
    }
    
    func testEmptyCSVGeneration() {
        let results: [PingResult] = []
        let csv = Exporter.csvString(from: results)
        XCTAssertEqual(csv, "timestamp,sequence,host,bytes,ttl,rtt_ms,status")
    }

    // MARK: - RFC 4180 field escaping

    func testCSVFieldPassthroughForPlainValues() {
        XCTAssertEqual(Exporter.csvField("example.com"), "example.com")
        XCTAssertEqual(Exporter.csvField(""), "")
    }

    func testCSVFieldQuotesCommas() {
        XCTAssertEqual(Exporter.csvField("a,b"), "\"a,b\"")
    }

    func testCSVFieldEscapesEmbeddedQuotes() {
        XCTAssertEqual(Exporter.csvField(#"say "hi""#), #""say ""hi""""#)
    }

    func testCSVFieldQuotesNewlines() {
        XCTAssertEqual(Exporter.csvField("line1\nline2"), "\"line1\nline2\"")
    }

    /// A DNS TXT value with commas must stay in one column.
    func testCSVRowStaysAlignedWithCommaValue() {
        let row = "\(Exporter.csvField("v=spf1, include:x.com")),300"
        XCTAssertEqual(row, "\"v=spf1, include:x.com\",300")
    }
}
