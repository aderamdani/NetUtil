import XCTest
@testable import NetUtil

final class BonjourTests: XCTestCase {
    func testServicePresetCount() {
        let vm = BonjourBrowserViewModel()
        XCTAssertEqual(vm.availableServiceTypes.count, 12)
    }
    
    func testServiceInit() {
        let service = BonjourService(name: "Test", type: "_http._tcp", domain: "local.")
        XCTAssertEqual(service.name, "Test")
        XCTAssertEqual(service.type, "_http._tcp")
        XCTAssertEqual(service.domain, "local.")
    }
}
