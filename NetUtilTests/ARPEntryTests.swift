import XCTest
@testable import NetUtil

@MainActor
final class ARPEntryTests: XCTestCase {

    private let sample = """
    ? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
    ? (192.168.1.50) at (incomplete) on en0 ifscope [ethernet]
    ? (192.168.1.255) at ff:ff:ff:ff:ff:ff on en0 ifscope [ethernet]
    ? (224.0.0.251) at 1:0:5e:0:0:fb on en0 ifscope permanent [ethernet]
    garbage line without structure
    """

    func testParsesEntries() {
        let entries = ARPEntry.parse(sample)
        XCTAssertEqual(entries.count, 4, "garbage lines must be skipped")

        let router = entries[0]
        XCTAssertEqual(router.ip, "192.168.1.1")
        XCTAssertEqual(router.mac, "aa:bb:cc:dd:ee:ff")
        XCTAssertEqual(router.interface, "en0")
        XCTAssertEqual(router.kind, .host)
        XCTAssertFalse(router.isPermanent)
    }

    func testIncompleteEntryHasNilMAC() {
        let entries = ARPEntry.parse(sample)
        XCTAssertNil(entries[1].mac)
        XCTAssertEqual(entries[1].kind, .host)
    }

    func testKindClassification() {
        let entries = ARPEntry.parse(sample)
        XCTAssertEqual(entries[2].kind, .broadcast)
        XCTAssertEqual(entries[3].kind, .multicast)
        XCTAssertTrue(entries[3].isPermanent)
    }

    func testEmptyOutput() {
        XCTAssertTrue(ARPEntry.parse("").isEmpty)
    }
}
