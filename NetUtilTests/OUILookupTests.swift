import XCTest
@testable import NetUtil

final class OUILookupTests: XCTestCase {
    func testKnownVendorAndCategory() {
        XCTAssertEqual(OUILookup.vendor(for: "AC:DE:48:12:34:56"), "Apple")
        XCTAssertEqual(OUILookup.deviceCategory(for: "AC:DE:48:12:34:56"), "Computer")
        XCTAssertEqual(OUILookup.vendor(for: "B8:27:EB:00:11:22"), "Raspberry Pi")
        XCTAssertEqual(OUILookup.deviceCategory(for: "14:CC:20:00:11:22"), "Router")
        XCTAssertEqual(OUILookup.deviceCategory(for: "00:1F:29:00:11:22"), "Printer")
    }

    func testNormalizesCaseAndSeparators() {
        XCTAssertEqual(OUILookup.vendor(for: "ac-de-48-12-34-56"), "Apple")
        XCTAssertEqual(OUILookup.vendor(for: "ac:de:48:12:34:56"), "Apple")
    }

    func testUnknownPrefixReturnsNil() {
        XCTAssertNil(OUILookup.vendor(for: "02:00:00:00:00:00"))
        XCTAssertNil(OUILookup.deviceCategory(for: "not-a-mac"))
        XCTAssertNil(OUILookup.vendor(for: "AA:BB"))
    }

    func testARPEntryEnrichment() {
        let entry = ARPEntry(ip: "192.168.1.10", mac: "B8:27:EB:AA:BB:CC",
                             interface: "en0", isPermanent: false)
        XCTAssertEqual(entry.vendor, "Raspberry Pi")
        XCTAssertEqual(entry.deviceCategory, "Computer")

        let unresolved = ARPEntry(ip: "192.168.1.11", mac: nil,
                                  interface: "en0", isPermanent: false)
        XCTAssertNil(unresolved.vendor)
    }
}
