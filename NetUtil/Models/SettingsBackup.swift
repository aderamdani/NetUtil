import Foundation

/// Versioned, local-first settings backup. Pure data + pure collect/apply
/// helpers — no UI, no panels — so everything here is unit-testable.
/// Only whitelisted keys are ever read or written (see
/// `SettingsBackupWhitelist`); foreign keys are ignored on import, which
/// also keeps `ToolCatalog`-style forward compatibility.
struct SettingsBackup: Codable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let appVersion: String
    let exportedAt: Date
    let values: [String: BackupValue]

    init(values: [String: BackupValue], appVersion: String, exportedAt: Date = Date()) {
        self.schemaVersion = Self.currentSchemaVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.values = values
    }

    /// Decodes and validates. Unknown schema versions are rejected with a
    /// typed error — never a crash, never a partial apply.
    static func decode(from data: Data) throws -> SettingsBackup {
        let backup = try JSONDecoder().decode(SettingsBackup.self, from: data)
        guard backup.schemaVersion == currentSchemaVersion else {
            throw BackupError.unsupportedSchema(version: backup.schemaVersion)
        }
        return backup
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Gathers whitelisted keys from the given store. Keys absent from the
    /// store are skipped, so a fresh install exports a minimal file.
    static func collect(from store: UserDefaults, includeHistory: Bool, appVersion: String) -> SettingsBackup {
        var values: [String: BackupValue] = [:]
        for entry in SettingsBackupWhitelist.entries(includeHistory: includeHistory) {
            guard store.object(forKey: entry.key) != nil else { continue }
            switch entry.kind {
            case .bool:
                values[entry.key] = .bool(store.bool(forKey: entry.key))
            case .int:
                values[entry.key] = .int(store.integer(forKey: entry.key))
            case .double:
                values[entry.key] = .double(store.double(forKey: entry.key))
            case .data:
                if let data = store.data(forKey: entry.key) {
                    values[entry.key] = .data(data)
                }
            case .strings:
                if let array = store.stringArray(forKey: entry.key) {
                    values[entry.key] = .strings(array)
                }
            }
        }
        return SettingsBackup(values: values, appVersion: appVersion)
    }

    /// Writes only whitelisted keys present in the backup. Foreign keys
    /// are skipped without touching the store. Returns the keys written.
    @discardableResult
    static func apply(_ backup: SettingsBackup, to store: UserDefaults) -> [String] {
        var written: [String] = []
        for (key, value) in backup.values {
            guard SettingsBackupWhitelist.allKeys.contains(key) else { continue }
            store.set(value.object, forKey: key)
            written.append(key)
        }
        return written
    }
}

enum BackupError: Error, Equatable, Sendable {
    case unsupportedSchema(version: Int)
}

/// A primitive settings value. `strings` covers `[String]`-backed keys
/// (disabled tools, host history); `data` covers JSON blobs (favorites,
/// watchlist, session history, traffic totals).
enum BackupValue: Codable, Sendable, Hashable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case data(Data)
    case strings([String])

    private enum Kind: String, Codable {
        case bool, int, double, string, data, strings
    }

    private enum CodingKeys: String, CodingKey {
        case kind, value
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        switch try box.decode(Kind.self, forKey: .kind) {
        case .bool:    self = .bool(try box.decode(Bool.self, forKey: .value))
        case .int:     self = .int(try box.decode(Int.self, forKey: .value))
        case .double:  self = .double(try box.decode(Double.self, forKey: .value))
        case .string:  self = .string(try box.decode(String.self, forKey: .value))
        case .data:    self = .data(try box.decode(Data.self, forKey: .value))
        case .strings: self = .strings(try box.decode([String].self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .bool(let value):
            try box.encode(Kind.bool, forKey: .kind)
            try box.encode(value, forKey: .value)
        case .int(let value):
            try box.encode(Kind.int, forKey: .kind)
            try box.encode(value, forKey: .value)
        case .double(let value):
            try box.encode(Kind.double, forKey: .kind)
            try box.encode(value, forKey: .value)
        case .string(let value):
            try box.encode(Kind.string, forKey: .kind)
            try box.encode(value, forKey: .value)
        case .data(let value):
            try box.encode(Kind.data, forKey: .kind)
            try box.encode(value, forKey: .value)
        case .strings(let value):
            try box.encode(Kind.strings, forKey: .kind)
            try box.encode(value, forKey: .value)
        }
    }

    /// Raw plist object for writing back to UserDefaults.
    var object: Any {
        switch self {
        case .bool(let value):    return value
        case .int(let value):     return value
        case .double(let value):  return value
        case .string(let value):  return value
        case .data(let value):    return value
        case .strings(let value): return value
        }
    }
}

/// Explicit export whitelist, audited from `@AppStorage` declarations and
/// model storage keys — never a blanket dump. History keys (scanned
/// hosts, traffic totals) stay out unless `includeHistory` is set.
enum SettingsBackupWhitelist {
    enum Kind: Sendable {
        case bool, int, double, data, strings
    }

    struct Entry: Sendable {
        let key: String
        let kind: Kind
    }

    /// General pane (10) + Thresholds (3) + Tools (5) + Privacy (1) + Multi-Ping alerts toggle.
    static let preferences: [Entry] = [
        Entry(key: "defaultPingCount", kind: .int),
        Entry(key: "defaultPingInterval", kind: .double),
        Entry(key: "pingAutoStopLimit", kind: .int),
        Entry(key: "pingBeepOnLoss", kind: .bool),
        Entry(key: "pingAlerts", kind: .bool),
        Entry(key: "defaultMaxHops", kind: .int),
        Entry(key: "defaultTraceInterval", kind: .double),
        Entry(key: "maxRawLines", kind: .int),
        Entry(key: "backgroundOnClose", kind: .bool),
        Entry(key: "menuBarShowTraffic", kind: .bool),
        Entry(key: "rttWarnThreshold", kind: .double),
        Entry(key: "rttCritThreshold", kind: .double),
        Entry(key: "lossAlertThreshold", kind: .double),
        Entry(key: "multiPingAlerts", kind: .bool),
        Entry(key: "portScanTimeout", kind: .double),
        Entry(key: "portScanConcurrency", kind: .int),
        Entry(key: "httpTimeout", kind: .double),
        Entry(key: "sslTimeout", kind: .double),
        Entry(key: "bandwidthInterval", kind: .double),
        Entry(key: "geoEnabled", kind: .bool),
    ]

    /// Tool availability, favorites, SSL watchlist.
    static let configuration: [Entry] = [
        Entry(key: "com.netutil.disabledTools", kind: .strings),
        Entry(key: "com.netutil.favorites", kind: .data),
        Entry(key: "com.netutil.sslWatchlist", kind: .data),
    ]

    /// Opt-in only: these reveal scanned hosts and traffic volumes.
    static let history: [Entry] = [
        Entry(key: "com.netutil.sessionHistory", kind: .data),
        Entry(key: "trafficStatisticsDaily", kind: .data),
        Entry(key: "netutil.hostHistory", kind: .strings),
    ]

    static func entries(includeHistory: Bool) -> [Entry] {
        preferences + configuration + (includeHistory ? history : [])
    }

    static let allKeys: Set<String> = Set(
        (preferences + configuration + history).map(\.key)
    )
}
