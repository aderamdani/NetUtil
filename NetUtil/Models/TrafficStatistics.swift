import Foundation
import Combine

/// Persistent traffic statistics — stores daily totals to UserDefaults.
@MainActor
class TrafficStatistics: ObservableObject {
    @Published var dailyTotals: [DayTotal] = []
    @Published var sessionStart: Date = Date()
    @Published var sessionRxBytes: UInt64 = 0
    @Published var sessionTxBytes: UInt64 = 0

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
