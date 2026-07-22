import XCTest
@testable import NetUtil

@MainActor
final class HTTPLatencyResultTests: XCTestCase {
    
    func testInitWithAllFields() {
        let timestamp = Date()
        let phases = [HTTPPhaseTiming(phase: .dns, startMs: 0, durationMs: 10)]
        let result = HTTPLatencyResult(
            url: "https://example.com",
            method: "GET",
            statusCode: 200,
            totalMs: 100,
            phases: phases,
            bodyBytes: 1024,
            redirectCount: 0,
            timestamp: timestamp
        )
        
        XCTAssertEqual(result.url, "https://example.com")
        XCTAssertEqual(result.method, "GET")
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.totalMs, 100)
        XCTAssertEqual(result.phases.count, 1)
        XCTAssertEqual(result.bodyBytes, 1024)
        XCTAssertEqual(result.redirectCount, 0)
        XCTAssertEqual(result.timestamp, timestamp)
    }
    
    func testEdgeCases() {
        let result = HTTPLatencyResult(
            url: "",
            method: "",
            statusCode: nil,
            totalMs: 0,
            phases: [],
            bodyBytes: nil,
            redirectCount: 0,
            timestamp: Date()
        )
        
        XCTAssertEqual(result.totalMs, 0)
        XCTAssertNil(result.statusCode)
        XCTAssertTrue(result.phases.isEmpty)
    }
}
