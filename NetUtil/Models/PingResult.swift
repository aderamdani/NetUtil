import Foundation

struct PingResult: Identifiable {
    let id = UUID()
    let sequence: Int
    let bytes: Int
    let host: String
    let ttl: Int
    let rtt: Double
    let timestamp: Date = Date()
}

struct PingStats {
    var transmitted: Int = 0
    var received: Int = 0
    var minRtt: Double = .infinity
    var maxRtt: Double = 0
    var avgRtt: Double = 0
    var jitter: Double = 0
    private var totalRtt: Double = 0
    private var sumSquares: Double = 0

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
    }

    mutating func recordTimeout() {
        transmitted += 1
    }
}
