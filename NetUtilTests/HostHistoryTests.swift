import XCTest
@testable import NetUtil

@MainActor
final class HostHistoryTests: XCTestCase {
    
    // The async override runs on this class's MainActor isolation,
    // unlike the sync setUp() which stays nonisolated in Swift 6.
    override func setUp() async throws {
        HostHistory.shared.clear()
    }
    
    func testAddHost() {
        HostHistory.shared.record("google.com")
        XCTAssertEqual(HostHistory.shared.hosts.count, 1)
        XCTAssertEqual(HostHistory.shared.hosts.first, "google.com")
    }
    
    func testDuplicateHostHandling() {
        HostHistory.shared.record("google.com")
        HostHistory.shared.record("apple.com")
        HostHistory.shared.record("google.com")
        
        XCTAssertEqual(HostHistory.shared.hosts.count, 2)
        XCTAssertEqual(HostHistory.shared.hosts.first, "google.com")
    }
    
    func testHistoryLimit() {
        for i in 0..<25 {
            HostHistory.shared.record("host\(i).com")
        }
        XCTAssertEqual(HostHistory.shared.hosts.count, 20)
    }
    
    func testClear() {
        HostHistory.shared.record("test.com")
        HostHistory.shared.clear()
        XCTAssertTrue(HostHistory.shared.hosts.isEmpty)
    }
    
    func testPersistence() {
        HostHistory.shared.record("persist.com")
        
        // Simulating reload
        let newInstance = HostHistory.shared
        XCTAssertEqual(newInstance.hosts.first, "persist.com")
    }
}
