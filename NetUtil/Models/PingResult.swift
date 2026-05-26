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
    private var totalRtt: Double = 0

    var loss: Double {
        transmitted == 0 ? 0 : Double(transmitted - received) / Double(transmitted) * 100
    }

    mutating func record(rtt: Double) {
        received += 1
        totalRtt += rtt
        if rtt < minRtt { minRtt = rtt }
        if rtt > maxRtt { maxRtt = rtt }
        avgRtt = totalRtt / Double(received)
    }

    mutating func recordTimeout() {
        transmitted += 1
    }
}
