import Foundation

struct GeoInfo {
    let country: String
    let city: String
    let org: String

    var flag: String {
        let base: UInt32 = 127397
        return country.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map(String.init).joined()
    }

    var shortLabel: String { "\(flag) \(city.isEmpty ? country : city)" }
}

struct RTTSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let rtt: Double?
}

struct TracerouteHop: Identifiable {
    let id = UUID()
    let hop: Int
    var host: String?
    var ip: String?
    var rtts: [Double?]
    var samples: [RTTSample]
    var lastSeen: Date = Date()
    var geo: GeoInfo?

    private static let historyLimit = 100

    var displayHost: String {
        guard host != nil || ip != nil else { return "*" }
        if let h = host, let i = ip, h != i { return "\(h) (\(i))" }
        return host ?? ip ?? "*"
    }

    var sent: Int { samples.count }

    var loss: Double {
        guard !samples.isEmpty else { return 0 }
        return Double(samples.filter { $0.rtt == nil }.count) / Double(samples.count) * 100
    }

    private var validSamples: [Double] { samples.compactMap { $0.rtt } }

    var lastRtt: Double? { samples.last?.rtt ?? nil }
    var avgRtt: Double? {
        guard !validSamples.isEmpty else { return nil }
        return validSamples.reduce(0, +) / Double(validSamples.count)
    }
    var minRtt: Double? { validSamples.min() }
    var maxRtt: Double? { validSamples.max() }
    var jitter: Double? {
        let v = validSamples
        guard v.count > 1, let avg = avgRtt else { return nil }
        let variance = v.map { pow($0 - avg, 2) }.reduce(0, +) / Double(v.count)
        return sqrt(variance)
    }
    var consecutiveLoss: Int {
        var n = 0
        for s in samples.reversed() { if s.rtt == nil { n += 1 } else { break } }
        return n
    }

    mutating func appendRound(_ rtts: [Double?], at timestamp: Date) {
        let valid = rtts.compactMap { $0 }
        let avgRtt = valid.isEmpty ? nil : valid.reduce(0, +) / Double(valid.count)
        samples.append(RTTSample(timestamp: timestamp, rtt: avgRtt))
        if samples.count > Self.historyLimit {
            samples.removeFirst(samples.count - Self.historyLimit)
        }
    }
}
