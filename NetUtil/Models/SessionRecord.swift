import Foundation
import Observation

enum SessionStatus: String, Codable {
    case success, partial, failed

    var color: String {
        switch self {
        case .success: "green"
        case .partial: "orange"
        case .failed:  "red"
        }
    }
}

// Compact snapshots for Compare feature
struct PortResultSnapshot: Codable, Identifiable {
    var id: UUID = UUID()
    let port: Int
    let service: String?
    let isOpen: Bool
}

struct HopSnapshot: Codable, Identifiable {
    var id: UUID = UUID()
    let hop: Int
    let host: String?
    let avgRttMs: Double?
}

struct PingStatsSnapshot: Codable {
    let transmitted: Int
    let received: Int
    let avgRtt: Double
    let minRtt: Double
    let maxRtt: Double
    let jitter: Double

    var lossPercent: Double {
        transmitted > 0 ? Double(transmitted - received) / Double(transmitted) * 100 : 0
    }
}

struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let tool: String
    let target: String
    let timestamp: Date
    var duration: TimeInterval
    var summary: String
    var status: SessionStatus

    // Optional detail — retained for most recent 20 records only
    var portResults: [PortResultSnapshot]?
    var tracerouteHops: [HopSnapshot]?
    var pingStats: PingStatsSnapshot?

    init(tool: String, target: String, summary: String, status: SessionStatus, duration: TimeInterval = 0) {
        self.id        = UUID()
        self.tool      = tool
        self.target    = target
        self.timestamp = Date()
        self.duration  = duration
        self.summary   = summary
        self.status    = status
    }
}

@Observable
@MainActor
final class SessionHistory {
    var records: [SessionRecord] = []
    private let key = "com.netutil.sessionHistory"
    private let maxRecords = 200
    private let maxDetailRecords = 20

    init() { load() }

    func log(_ record: SessionRecord) {
        records.insert(record, at: 0)
        pruneDetail()
        if records.count > maxRecords { records = Array(records.prefix(maxRecords)) }
        save()
    }

    func remove(id: UUID) { records.removeAll { $0.id == id }; save() }
    func clear() { records.removeAll(); save() }

    func records(forTool tool: String) -> [SessionRecord] {
        records.filter { $0.tool == tool }
    }

    func csvString() -> String {
        let fmt = ISO8601DateFormatter()
        let header = "timestamp,tool,target,status,duration_s,summary"
        let rows = records.map {
            "\(fmt.string(from: $0.timestamp)),\($0.tool),\"\($0.target)\",\($0.status.rawValue),\(String(format: "%.1f", $0.duration)),\"\($0.summary)\""
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private func pruneDetail() {
        var detailCount = 0
        for i in 0..<records.count {
            guard records[i].portResults != nil || records[i].tracerouteHops != nil || records[i].pingStats != nil else { continue }
            detailCount += 1
            if detailCount > maxDetailRecords {
                records[i].portResults = nil
                records[i].tracerouteHops = nil
                records[i].pingStats = nil
            }
        }
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data) else { return }
        records = decoded
    }
}
