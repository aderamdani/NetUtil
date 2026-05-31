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
        XCTAssertEqual(csv, "timestamp,sequence,host,bytes,ttl,rtt_ms")
    }
}
