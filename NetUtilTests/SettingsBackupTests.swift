import XCTest
@testable import NetUtil

/// Round-trip, whitelist, schema, privacy-default, and apply tests for
/// the settings backup engine. Pure logic only — injectable UserDefaults
/// suites, no panels, no `.standard` touched.
@MainActor
final class SettingsBackupTests: XCTestCase {
    private var store: UserDefaults!
    private let suiteName = "NetUtilTests-SettingsBackup"

    override func setUp() async throws {
        guard let suite = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create test defaults suite")
        }
        store = suite
        store.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Round trip

    func testRoundTripAllValueTypes() throws {
        let values: [String: BackupValue] = [
            "b": .bool(true),
            "i": .int(42),
            "d": .double(1.5),
            "s": .string("hello"),
            "data": .data(Data("blob".utf8)),
            "arr": .strings(["a", "b"]),
        ]
        let backup = SettingsBackup(values: values, appVersion: "test")
        let decoded = try SettingsBackup.decode(from: backup.encoded())
        XCTAssertEqual(decoded.schemaVersion, SettingsBackup.currentSchemaVersion)
        XCTAssertEqual(decoded.appVersion, "test")
        XCTAssertEqual(decoded.values, values)
    }

    // MARK: - Whitelist

    func testCollectOnlyIncludesWhitelistedKeys() {
        store.set(true, forKey: "pingAlerts")
        store.set(123, forKey: "not.in.whitelist")
        store.set("x", forKey: "NSGlobalDomain-Evil")

        let backup = SettingsBackup.collect(from: store, includeHistory: false, appVersion: "test")
        XCTAssertTrue(backup.values.keys.allSatisfy(SettingsBackupWhitelist.allKeys.contains))
        XCTAssertEqual(backup.values["pingAlerts"], .bool(true))
        XCTAssertNil(backup.values["not.in.whitelist"])
        XCTAssertNil(backup.values["NSGlobalDomain-Evil"])
    }

    func testCollectSkipsAbsentKeys() {
        let backup = SettingsBackup.collect(from: store, includeHistory: true, appVersion: "test")
        XCTAssertTrue(backup.values.isEmpty)
    }

    // MARK: - Schema versions

    func testUnsupportedSchemaRejected() {
        let json = """
        {"schemaVersion":999,"appVersion":"x","exportedAt":784080000,"values":{}}
        """
        guard let data = json.data(using: .utf8) else {
            XCTFail("Test fixture is not UTF-8")
            return
        }
        XCTAssertThrowsError(try SettingsBackup.decode(from: data)) { error in
            XCTAssertEqual(error as? BackupError, .unsupportedSchema(version: 999))
        }
    }

    func testGarbageDataRejectedWithoutCrash() {
        guard let data = "not json".data(using: .utf8) else {
            XCTFail("Test fixture is not UTF-8")
            return
        }
        XCTAssertThrowsError(try SettingsBackup.decode(from: data))
    }

    // MARK: - Privacy default

    func testHistoryExcludedByDefault() {
        store.set(Data("sessions".utf8), forKey: "com.netutil.sessionHistory")
        store.set(Data("totals".utf8), forKey: "trafficStatisticsDaily")
        store.set(["example.com"], forKey: "netutil.hostHistory")
        store.set(false, forKey: "menuBarShowTraffic")

        let excluded = SettingsBackup.collect(from: store, includeHistory: false, appVersion: "test")
        XCTAssertNil(excluded.values["com.netutil.sessionHistory"])
        XCTAssertNil(excluded.values["trafficStatisticsDaily"])
        XCTAssertNil(excluded.values["netutil.hostHistory"])
        XCTAssertEqual(excluded.values["menuBarShowTraffic"], .bool(false))

        let included = SettingsBackup.collect(from: store, includeHistory: true, appVersion: "test")
        XCTAssertEqual(included.values["com.netutil.sessionHistory"], .data(Data("sessions".utf8)))
        XCTAssertEqual(included.values["trafficStatisticsDaily"], .data(Data("totals".utf8)))
        XCTAssertEqual(included.values["netutil.hostHistory"], .strings(["example.com"]))
    }

    // MARK: - Apply

    func testApplyWritesWhitelistedAndIgnoresForeign() {
        let backup = SettingsBackup(values: [
            "pingAlerts": .bool(true),
            "defaultPingCount": .int(30),
            "defaultPingInterval": .double(0.5),
            "com.netutil.disabledTools": .strings(["ping"]),
            "not.in.whitelist": .string("evil"),
        ], appVersion: "test")

        let written = SettingsBackup.apply(backup, to: store)
        XCTAssertEqual(Set(written), ["pingAlerts", "defaultPingCount", "defaultPingInterval",
                                      "com.netutil.disabledTools"])
        XCTAssertTrue(store.bool(forKey: "pingAlerts"))
        XCTAssertEqual(store.integer(forKey: "defaultPingCount"), 30)
        XCTAssertEqual(store.double(forKey: "defaultPingInterval"), 0.5, accuracy: 0.0001)
        XCTAssertEqual(store.stringArray(forKey: "com.netutil.disabledTools"), ["ping"])
        XCTAssertNil(store.object(forKey: "not.in.whitelist"))
    }

    func testApplyPartialBackupLeavesRestUntouched() {
        store.set(true, forKey: "pingAlerts")
        let backup = SettingsBackup(values: ["menuBarShowTraffic": .bool(true)], appVersion: "test")

        SettingsBackup.apply(backup, to: store)
        XCTAssertTrue(store.bool(forKey: "pingAlerts"))
        XCTAssertTrue(store.bool(forKey: "menuBarShowTraffic"))
    }
}
