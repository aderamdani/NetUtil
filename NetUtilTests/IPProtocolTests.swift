import XCTest
@testable import NetUtil

final class IPProtocolTests: XCTestCase {
    func testNumbers() {
        XCTAssertEqual(IPProtocol.name(forNumber: 6), "TCP")
        XCTAssertEqual(IPProtocol.name(forNumber: 17), "UDP")
        XCTAssertEqual(IPProtocol.name(forNumber: 58), "ICMPv6")
        XCTAssertEqual(IPProtocol.name(forNumber: 99), "IP(99)")
    }

    func testCanonical() {
        XCTAssertEqual(IPProtocol.canonical("tcp"), "TCP")
        XCTAssertEqual(IPProtocol.canonical("UDP"), "UDP")
        XCTAssertEqual(IPProtocol.canonical("6"), "TCP")
        XCTAssertEqual(IPProtocol.canonical("icmpv6"), "ICMPv6")
        XCTAssertNil(IPProtocol.canonical("bogus"))
    }
}
