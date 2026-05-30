import Foundation
import Combine
import Observation

/// Persistent traffic statistics — stores daily totals to UserDefaults.
@MainActor
@Observable
final class TrafficStatistics {
    var dailyTotals: [DayTotal] = []
    var sessionStart: Date = Date()
    var sessionRxBytes: UInt64 = 0
    var sessionTxBytes: UInt64 = 0

    var todayRx: UInt64 { dailyTotals.last?.rxBytes ?? 0 }
    var todayTx: UInt64 { dailyTotals.last?.txBytes ?? 0 }
    
    var totalRx: UInt64 { dailyTotals.map(\.rxBytes).reduce(0, &+) }
    var totalTx: UInt64 { dailyTotals.map(\.txBytes).reduce(0, &+) }
    
    var averageDailyRx: UInt64 { dailyTotals.isEmpty ? 0 : totalRx / UInt64(dailyTotals.count) }
    var averageDailyTx: UInt64 { dailyTotals.isEmpty ? 0 : totalTx / UInt64(dailyTotals.count) }

    struct DayTotal: Identifiable, Codable {
        var id: String { dateKey }
        let dateKey: String  // "yyyy-MM-dd"
        var rxBytes: UInt64
        var txBytes: UInt64
    }

    private static let storeKey = "trafficStatisticsDaily"
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init() { load() }

    /// Called every second by ToolStore's BandwidthMonitor with the latest aggregate sample.
    func record(rxDelta: UInt64, txDelta: UInt64) {
        guard rxDelta > 0 || txDelta > 0 else { return }
        sessionRxBytes &+= rxDelta
        sessionTxBytes &+= txDelta

        let key = Self.formatter.string(from: Date())
        if let idx = dailyTotals.firstIndex(where: { $0.dateKey == key }) {
            dailyTotals[idx].rxBytes &+= rxDelta
            dailyTotals[idx].txBytes &+= txDelta
        } else {
            dailyTotals.append(DayTotal(dateKey: key, rxBytes: rxDelta, txBytes: txDelta))
            if dailyTotals.count > 90 { dailyTotals.removeFirst() }
        }
        save()
    }

    func reset() {
        dailyTotals = []
        sessionRxBytes = 0
        sessionTxBytes = 0
        sessionStart = Date()
        UserDefaults.standard.removeObject(forKey: Self.storeKey)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(dailyTotals) else { return }
        UserDefaults.standard.set(data, forKey: Self.storeKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storeKey),
              let arr = try? JSONDecoder().decode([DayTotal].self, from: data) else { return }
        dailyTotals = arr
    }
}
