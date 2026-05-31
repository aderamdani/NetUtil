import XCTest
@testable import NetUtil

final class SpeedTestModelsTests: XCTestCase {
    
    func testResultInitialization() {
        let now = Date()
        let result = SpeedTestResult(timestamp: now, kind: .speed, provider: "ISP")
        
        XCTAssertEqual(result.timestamp, now)
        XCTAssertEqual(result.kind, .speed)
        XCTAssertEqual(result.provider, "ISP")
        XCTAssertEqual(result.downloadMbps, 0)
    }
}
