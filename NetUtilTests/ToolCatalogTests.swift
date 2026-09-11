import XCTest
@testable import NetUtil

/// Identity, grouping, availability, migration, and selection-fallback
/// tests for the modular tool catalog. Synchronous, no timers.
@MainActor
final class ToolCatalogTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() async throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: "NetUtilTests-ToolCatalog"))
        defaults.removePersistentDomain(forName: "NetUtilTests-ToolCatalog")
    }

    private func makeCatalog() -> ToolCatalog {
        ToolCatalog(store: defaults)
    }

    // MARK: - Identity

    func testPersistenceKeysAreUnique() {
        let keys = Tool.allCases.map(\.persistenceKey)
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testPersistenceKeysAreStable() {
        let expected: [Tool: String] = [
            .dashboard: "dashboard", .doctor: "doctor", .ping: "ping",
            .traceroute: "traceroute", .multiPing: "multiPing", .portScan: "portScan",
            .subnetScan: "subnetScan", .httpLatency: "httpLatency", .pathMTU: "pathMTU",
            .subnet: "subnet", .dns: "dns", .ssl: "ssl", .whois: "whois",
            .bandwidth: "bandwidth", .interfaces: "interfaces", .wifi: "wifi",
            .routes: "routes", .neighbors: "neighbors", .connections: "connections",
            .statistics: "statistics", .speedTest: "speedTest", .netQuality: "netQuality",
            .wakeOnLAN: "wakeOnLAN", .portListener: "portListener",
            .ipGeolocation: "ipGeolocation", .dnsResolver: "dnsResolver",
            .sessionHistory: "sessionHistory", .compare: "compare",
        ]
        XCTAssertEqual(expected.count, Tool.allCases.count)
        for (tool, key) in expected {
            XCTAssertEqual(tool.persistenceKey, key)
            XCTAssertEqual(Tool(persistenceKey: key), tool)
        }
        XCTAssertNil(Tool(persistenceKey: "no-such-tool"))
    }

    // MARK: - Grouping

    func testGroupsCoverAllToolsExactlyOnce() {
        let grouped = ToolGroup.allCases.flatMap(\.tools)
        XCTAssertEqual(grouped.count, Tool.allCases.count)
        XCTAssertEqual(Set(grouped.map(\.persistenceKey)).count, Tool.allCases.count)
    }

    func testGroupOrderMatchesSidebar() {
        XCTAssertEqual(ToolGroup.allCases.map(\.title),
                       [nil, "Active Probing", "IP Toolbox", "Lookup & Security",
                        "Bandwidth", "Network Status"])
    }

    func testGroupMembership() {
        XCTAssertEqual(Tool.ping.group, .activeProbing)
        XCTAssertEqual(Tool.traceroute.group, .activeProbing)
        XCTAssertEqual(Tool.pathMTU.group, .activeProbing)
        XCTAssertEqual(Tool.subnet.group, .ipToolbox)
        XCTAssertEqual(Tool.wakeOnLAN.group, .ipToolbox)
        XCTAssertEqual(Tool.ipGeolocation.group, .ipToolbox)
        XCTAssertEqual(Tool.ssl.group, .lookupSecurity)
        XCTAssertEqual(Tool.dnsResolver.group, .lookupSecurity)
        XCTAssertEqual(Tool.bandwidth.group, .bandwidth)
        XCTAssertEqual(Tool.speedTest.group, .bandwidth)
        XCTAssertEqual(Tool.interfaces.group, .networkStatus)
        XCTAssertEqual(Tool.neighbors.group, .networkStatus)
        XCTAssertEqual(Tool.dashboard.group, .core)
        XCTAssertEqual(Tool.doctor.group, .core)
        XCTAssertEqual(Tool.sessionHistory.group, .core)
        XCTAssertEqual(Tool.compare.group, .core)
    }

    // MARK: - Availability

    func testCatalogDefaultsToAllAvailable() {
        let catalog = makeCatalog()
        for tool in Tool.allCases {
            XCTAssertTrue(catalog.isAvailable(tool))
        }
        XCTAssertEqual(catalog.availableTools(in: .core).count, 4)
        XCTAssertEqual(catalog.availableTools(in: .activeProbing).count, 6)
        XCTAssertEqual(catalog.availableTools(in: .ipToolbox).count, 5)
        XCTAssertEqual(catalog.availableTools(in: .lookupSecurity).count, 4)
        XCTAssertEqual(catalog.availableTools(in: .bandwidth).count, 4)
        XCTAssertEqual(catalog.availableTools(in: .networkStatus).count, 5)
    }

    func testCatalogToggleRoundTripsThroughStorage() {
        let catalog = makeCatalog()
        catalog.setAvailable(.ping, false)
        XCTAssertFalse(catalog.isAvailable(.ping))
        XCTAssertTrue(catalog.availableTools(in: .activeProbing).allSatisfy { $0 != .ping })

        let reloaded = makeCatalog()
        XCTAssertFalse(reloaded.isAvailable(.ping))

        reloaded.setAvailable(.ping, true)
        XCTAssertTrue(makeCatalog().isAvailable(.ping))
    }

    func testCoreToolsCannotBeDisabled() {
        let catalog = makeCatalog()
        for tool in [Tool.dashboard, Tool.statistics, Tool.sessionHistory] {
            XCTAssertFalse(tool.canBeDisabled)
            catalog.setAvailable(tool, false)
            XCTAssertTrue(catalog.isAvailable(tool))
        }
        XCTAssertTrue(catalog.disabledKeys.isEmpty)
    }

    func testUnknownStoredKeysAreIgnored() {
        defaults.set(["ping", "bogus-tool"], forKey: "com.netutil.disabledTools")
        let catalog = makeCatalog()
        XCTAssertFalse(catalog.isAvailable(.ping))
        XCTAssertFalse(catalog.disabledKeys.contains("bogus-tool"))
    }

    // MARK: - Migration & fallback

    func testLegacySessionKeyMigration() {
        XCTAssertEqual(Tool.migratedSessionKey("IP Geolocation"), "ipGeolocation")
        XCTAssertEqual(Tool.migratedSessionKey("ping"), "ping")
        XCTAssertEqual(Tool.migratedSessionKey("ssl"), "ssl")
        XCTAssertEqual(Tool.migratedSessionKey("unknown"), "unknown")
    }

    func testFallbackSelection() {
        let all = Set(Tool.allCases.map(\.persistenceKey))
        XCTAssertNil(Tool.fallbackSelection(current: nil, availableKeys: all))
        XCTAssertEqual(Tool.fallbackSelection(current: .ping, availableKeys: all), .ping)

        let withoutPing = all.subtracting(["ping"])
        XCTAssertEqual(Tool.fallbackSelection(current: .ping, availableKeys: withoutPing), .dashboard)
        XCTAssertEqual(Tool.fallbackSelection(current: .dashboard, availableKeys: withoutPing), .dashboard)
    }
}
