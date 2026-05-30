import XCTest
@testable import NetUtilCore

final class IPAddressDetailsTests: XCTestCase {

    private func d(_ s: String) -> IPAddressDetails { IPAddressDetails(address: s) }

    func testClassDetection() {
        XCTAssertEqual(d("10.0.0.1").ipClass, "A")
        XCTAssertEqual(d("126.0.0.1").ipClass, "A")
        XCTAssertEqual(d("127.0.0.1").ipClass, "Loopback")
        XCTAssertEqual(d("128.0.0.1").ipClass, "B")
        XCTAssertEqual(d("191.255.0.1").ipClass, "B")
        XCTAssertEqual(d("192.0.0.1").ipClass, "C")
        XCTAssertEqual(d("223.0.0.1").ipClass, "C")
        XCTAssertEqual(d("224.0.0.1").ipClass, "D (Multicast)")
        XCTAssertEqual(d("240.0.0.1").ipClass, "E (Experimental)")
    }

    func testClassUnknownForMalformed() {
        XCTAssertEqual(d("1.2.3").ipClass, "Unknown")
        XCTAssertEqual(d("0.0.0.0").ipClass, "Unknown") // first octet 0 unhandled by design
    }

    func testIPv6Detection() {
        XCTAssertTrue(d("2607:f8b0::1").isIPv6)
        XCTAssertEqual(d("2607:f8b0::1").ipClass, "IPv6")
        XCTAssertFalse(d("8.8.8.8").isIPv6)
    }

    func testPrivateRFC1918() {
        XCTAssertTrue(d("10.255.0.1").isPrivate)
        XCTAssertTrue(d("172.16.0.1").isPrivate)
        XCTAssertTrue(d("172.31.255.255").isPrivate)
        XCTAssertTrue(d("192.168.1.1").isPrivate)
    }

    func testPrivateBoundariesArePublic() {
        XCTAssertFalse(d("172.15.0.1").isPrivate)
        XCTAssertFalse(d("172.32.0.1").isPrivate)
        XCTAssertFalse(d("8.8.8.8").isPrivate)
        XCTAssertFalse(d("11.0.0.1").isPrivate)
    }

    func testAPIPAIsPrivate() {
        XCTAssertTrue(d("169.254.1.1").isPrivate)
    }

    func testIPv6Private() {
        XCTAssertTrue(d("fe80::1").isPrivate)
        XCTAssertTrue(d("fd00::1").isPrivate)
        XCTAssertFalse(d("2607:f8b0::1").isPrivate)
    }
}
