import XCTest
@testable import NetUtil

@MainActor
final class DNSResolverEntryTests: XCTestCase {

    private let sampleOutput = """
    DNS configuration

    resolver #1
      nameserver[0] : 1.1.1.1
      flags    : Request A records
      reach    : 0x00000002 (Reachable)

    resolver #2
      domain   : local
      options  : mdns
      timeout  : 5
      flags    : Request A records
      reach    : 0x00000000 (Not Reachable)
      order    : 300000

    DNS configuration (for scoped queries)

    resolver #1
      nameserver[0] : 192.168.1.1
      if_index : 21 (en4)
      reach    : 0x00020002 (Reachable,Directly Reachable Address)
    """

    func testParsesGeneralAndScopedSections() {
        let entries = DNSResolverEntry.parse(sampleOutput)
        XCTAssertEqual(entries.count, 3)

        let general = entries.filter { !$0.isScoped }
        XCTAssertEqual(general.count, 2)
        XCTAssertEqual(general[0].nameservers, ["1.1.1.1"])
        XCTAssertTrue(general[0].isReachable)

        XCTAssertEqual(general[1].domain, "local")
        XCTAssertFalse(general[1].isReachable)
        XCTAssertTrue(general[1].nameservers.isEmpty)
    }

    func testParsesScopedResolverWithInterface() {
        let entries = DNSResolverEntry.parse(sampleOutput)
        let scoped = entries.filter { $0.isScoped }
        XCTAssertEqual(scoped.count, 1)
        XCTAssertEqual(scoped[0].nameservers, ["192.168.1.1"])
        XCTAssertEqual(scoped[0].interface, "en4")
        XCTAssertTrue(scoped[0].isReachable)
        XCTAssertEqual(scoped[0].scopeLabel, "Scoped (en4)")
    }

    func testEmptyOutputProducesNoEntries() {
        XCTAssertTrue(DNSResolverEntry.parse("").isEmpty)
    }

    func testNotReachableIsNotMisreadAsReachable() {
        // Regression: "Not Reachable" contains the substring "Reachable" —
        // a naive `.contains("Reachable")` check would misreport this as up.
        let output = """
        DNS configuration

        resolver #1
          domain   : local
          reach    : 0x00000000 (Not Reachable)
        """
        let entries = DNSResolverEntry.parse(output)
        XCTAssertEqual(entries.count, 1)
        XCTAssertFalse(entries[0].isReachable)
    }
}
