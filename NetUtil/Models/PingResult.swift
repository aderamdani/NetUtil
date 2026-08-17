import Foundation

enum PingStatus {
    case success
    case timeout
    case error
}

struct PingResult: Identifiable {
    let id = UUID()
    let sequence: Int
    let bytes: Int
    let host: String
    let ipAddress: String?
    let ttl: Int
    let rtt: Double
    let status: PingStatus
    let timestamp: Date = Date()
}

struct PingLogLine: Identifiable {
    let id = UUID()
    let text: String
}

struct PingStats {
    var transmitted: Int = 0
    var received: Int = 0
    var minRtt: Double = .infinity
    var maxRtt: Double = 0
    var avgRtt: Double = 0
    var jitter: Double = 0

    // Distribution buckets
    var bucketLow: Int = 0    // < 20ms
    var bucketMedium: Int = 0 // 20-50ms
    var bucketHigh: Int = 0   // 50-100ms
    var bucketCritical: Int = 0 // > 100ms

    private var totalRtt: Double = 0
    private var sumSquares: Double = 0

    /// Rolling window over the last `recentWindow` packets — a long or
    /// infinite run's lifetime average/​loss drags behind current conditions;
    /// these reflect "right now" instead.
    private static let recentWindow = 20
    private var recentRtts: [Double] = []
    private var recentOutcome: [Bool] = []   // true = received, false = timeout
    var recentAvgRtt: Double {
        recentRtts.isEmpty ? 0 : recentRtts.reduce(0, +) / Double(recentRtts.count)
    }
    var recentLoss: Double {
        guard !recentOutcome.isEmpty else { return 0 }
        let lost = recentOutcome.filter { !$0 }.count
        return Double(lost) / Double(recentOutcome.count) * 100
    }

    /// Number of packets contributing to the recent window (capped at
    /// `recentWindow`) — for "of the last N pings" alert copy.
    var recentCount: Int {
        min(max(transmitted, recentOutcome.count), Self.recentWindow)
    }

    var loss: Double {
        transmitted == 0 ? 0 : Double(transmitted - received) / Double(transmitted) * 100
    }

    mutating func record(rtt: Double) {
        transmitted += 1
        received += 1
        totalRtt += rtt
        sumSquares += rtt * rtt

        if rtt < minRtt { minRtt = rtt }
        if rtt > maxRtt { maxRtt = rtt }
        avgRtt = totalRtt / Double(received)

        if received > 1 {
            let variance = (sumSquares / Double(received)) - (avgRtt * avgRtt)
            jitter = sqrt(max(0, variance))
        }

        recentRtts.append(rtt)
        if recentRtts.count > Self.recentWindow {
            recentRtts.removeFirst(recentRtts.count - Self.recentWindow)
        }
        recentOutcome.append(true)
        if recentOutcome.count > Self.recentWindow {
            recentOutcome.removeFirst(recentOutcome.count - Self.recentWindow)
        }

        // Update buckets
        if rtt < 20 { bucketLow += 1 }
        else if rtt < 50 { bucketMedium += 1 }
        else if rtt < 100 { bucketHigh += 1 }
        else { bucketCritical += 1 }
    }

    mutating func recordTimeout() {
        transmitted += 1
        recentOutcome.append(false)
        if recentOutcome.count > Self.recentWindow {
            recentOutcome.removeFirst(recentOutcome.count - Self.recentWindow)
        }
    }
}
