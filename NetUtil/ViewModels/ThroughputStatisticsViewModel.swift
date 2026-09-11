import Foundation
import Observation

/// One throughput sample. Values are in bits per second.
struct ThroughputSample: Identifiable, Sendable {
    let id = UUID()
    let time: Date
    let download: Double
    let upload: Double
}

/// Selectable time window for the chart.
enum ThroughputRange: String, CaseIterable, Identifiable, Hashable, Sendable {
    case fiveMinutes = "5 min"
    case oneHour = "1 hour"
    case twelveHours = "12 hours"

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .fiveMinutes: return 5 * 60
        case .oneHour: return 60 * 60
        case .twelveHours: return 12 * 60 * 60
        }
    }

    /// X-axis tick density per range — keeps time labels from crowding.
    var stride: (component: Calendar.Component, count: Int) {
        switch self {
        case .fiveMinutes: return (.minute, 1)
        case .oneHour: return (.minute, 15)
        case .twelveHours: return (.hour, 2)
        }
    }
}

/// Data source contract — the view only ever sees filtered arrays.
protocol ThroughputDataProvider: Sendable {
    func samples(for range: ThroughputRange) async -> [ThroughputSample]
}

/// In-memory provider that filters a fixed sample set by recency.
struct StaticThroughputProvider: ThroughputDataProvider {
    let samples: [ThroughputSample]

    func samples(for range: ThroughputRange) async -> [ThroughputSample] {
        let cutoff = Date().addingTimeInterval(-range.seconds)
        return samples.filter { $0.time >= cutoff }
    }
}

@Observable
@MainActor
final class ThroughputStatisticsViewModel {
    var range: ThroughputRange = .fiveMinutes
    private(set) var samples: [ThroughputSample] = []
    private(set) var isLoading = false

    private let provider: any ThroughputDataProvider

    init(provider: any ThroughputDataProvider) {
        self.provider = provider
    }

    convenience init(samples: [ThroughputSample]) {
        self.init(provider: StaticThroughputProvider(samples: samples))
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        samples = await provider.samples(for: range)
    }

    private static let axisSteps = [1.0, 2, 2.5, 4, 5, 8, 10, 20, 25, 40, 50, 100]

    /// Snaps a peak up to a round binary multiple so the repo's bit-rate
    /// formatter prints axis labels like "20.00 M" instead of "19.13 M".
    static func axisTop(for peak: Double) -> Double {
        guard peak > 0 else { return 1024 }
        var unit = 1.0
        while peak / unit >= 1000 { unit *= 1024 }
        let target = peak * 1.1 / unit
        if let step = axisSteps.first(where: { $0 >= target }) { return step * unit }
        return ceil(target / 25) * 25 * unit
    }
}
