import XCTest
@testable import NetUtil

/// Consistency, audit-pin, and availability tests for the permission
/// transparency model (`Tool.networkUsage`, `PrivacyRow`).
@MainActor
final class ToolPrivacyTests: XCTestCase {

    private func hosts(of tool: Tool, scope: NetworkUsage.Scope? = nil) -> [String] {
        tool.networkUsage
            .filter { scope == nil || $0.scope == scope }
            .map(\.host)
    }

    // MARK: - Consistency

    func testEveryEntryHasHostAndPurpose() {
        for tool in Tool.allCases {
            for usage in tool.networkUsage {
                XCTAssertFalse(usage.host.isEmpty, "\(tool.persistenceKey) entry without host")
                XCTAssertFalse(usage.purpose.isEmpty, "\(tool.persistenceKey) entry without purpose")
            }
        }
    }

    func testLocalOnlyToolsHaveNoRemoteEntries() {
        for tool in Tool.allCases where tool.isLocalOnly {
            XCTAssertTrue(hosts(of: tool, scope: .remote).isEmpty,
                          "\(tool.persistenceKey) marked local-only but lists remote hosts")
        }
    }

    func testLocalOnlySnapshot() {
        let local = Set(Tool.allCases.filter(\.isLocalOnly).map(\.persistenceKey))
        XCTAssertEqual(local, ["bandwidth", "compare", "connections", "interfaces",
                               "neighbors", "routes", "sessionHistory", "statistics",
                               "subnet", "wakeOnLAN", "wifi"])
    }

    func testRemoteEntryCountSnapshot() {
        let total = Tool.allCases
            .flatMap(\.networkUsage)
            .filter { $0.scope == .remote }
            .count
        XCTAssertEqual(total, 22)
    }

    // MARK: - Audit pins (hosts verified against ViewModel/subprocess code)

    func testSpeedTestHosts() {
        let hosts = hosts(of: .speedTest)
        XCTAssertTrue(hosts.contains("speed.cloudflare.com"))
        XCTAssertTrue(hosts.contains("1.1.1.1"))
        XCTAssertTrue(hosts.contains { $0.contains("Google") && $0.contains("Reddit") })
    }

    func testDoctorHosts() {
        let doctorHosts = hosts(of: .doctor)
        XCTAssertTrue(doctorHosts.contains("captive.apple.com"))
        XCTAssertTrue(doctorHosts.contains("www.apple.com"))
        XCTAssertTrue(doctorHosts.contains("system DNS resolver"))
        XCTAssertEqual(hosts(of: .doctor, scope: .localOnly), ["default gateway (ICMP ping)"])
    }

    func testIPInfoConsumers() {
        for tool in [Tool.dashboard, Tool.traceroute, Tool.ipGeolocation] {
            XCTAssertTrue(hosts(of: tool).contains("ipinfo.io"), "\(tool.persistenceKey) should list ipinfo.io")
        }
        XCTAssertFalse(hosts(of: .dns).contains("ipinfo.io"))
    }

    func testDNSToolListsChosenServer() {
        XCTAssertEqual(hosts(of: .dns), ["chosen DNS server (System, 8.8.8.8, 1.1.1.1, 9.9.9.9)"])
        XCTAssertTrue(hosts(of: .dnsResolver).contains("configured DNS resolvers"))
    }

    func testPassiveToolsSendNothing() {
        for tool in [Tool.subnet, Tool.bandwidth, Tool.interfaces, Tool.wifi,
                     Tool.routes, Tool.neighbors, Tool.connections, Tool.statistics,
                     Tool.sessionHistory, Tool.compare] {
            XCTAssertTrue(tool.networkUsage.isEmpty, "\(tool.persistenceKey) should send no packets")
        }
    }

    func testListenerAndWakeOnLANScopes() {
        XCTAssertEqual(hosts(of: .portListener), ["any host (inbound only)"])
        XCTAssertFalse(Tool.portListener.isLocalOnly)
        XCTAssertEqual(hosts(of: .wakeOnLAN, scope: .remote), [])
        XCTAssertTrue(Tool.wakeOnLAN.isLocalOnly)
    }

    // MARK: - Privacy rows honor availability

    func testRemoteRowsCoverAllToolsByDefault() {
        let rows = PrivacyRow.remoteRows(for: Tool.allCases)
        XCTAssertEqual(rows.count, 22)
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
    }

    func testRemoteRowsExcludeDisabledTools() {
        let enabled = Tool.allCases.filter { $0 != .speedTest && $0 != .doctor }
        let rows = PrivacyRow.remoteRows(for: enabled)
        XCTAssertEqual(rows.count, 16)
        XCTAssertTrue(rows.allSatisfy { $0.tool != .speedTest && $0.tool != .doctor })
    }

    func testLocalOnlyHelperMatchesModel() {
        let local = Set(PrivacyRow.localOnlyTools(from: Tool.allCases).map(\.persistenceKey))
        XCTAssertEqual(local, Set(Tool.allCases.filter(\.isLocalOnly).map(\.persistenceKey)))
        XCTAssertEqual(local.count, 11)
    }
}
