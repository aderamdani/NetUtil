import XCTest
@testable import NetUtil

final class NetQualityOptionsTests: XCTestCase {
    func testDefault() {
        XCTAssertEqual(NetQualityViewModel.netQualityArguments(interface: nil, privateRelay: false), ["-c"])
    }

    func testInterfaceAndRelay() {
        XCTAssertEqual(NetQualityViewModel.netQualityArguments(interface: "en0", privateRelay: true), ["-c", "-I", "en0", "-p"])
    }

    func testEmptyInterfaceIgnored() {
        XCTAssertEqual(NetQualityViewModel.netQualityArguments(interface: "", privateRelay: false), ["-c"])
    }
}
