import XCTest
@testable import NetUtil

final class PingOptionsTests: XCTestCase {
    func testCountSizeTimeoutIntervalHost() {
        let args = PingViewModel.pingArguments(count: 5, packetSize: 64, timeoutMs: 1500, interval: 0.5, host: "example.com")
        XCTAssertEqual(args, ["-c", "5", "-s", "64", "-W", "1500", "-i", "0.5", "example.com"])
    }

    func testIntervalFloorAndOptionalOmissions() {
        let args = PingViewModel.pingArguments(count: nil, packetSize: nil, timeoutMs: nil, interval: 0.05, host: "1.1.1.1")
        XCTAssertEqual(args, ["-i", "0.2", "1.1.1.1"])
    }
}
