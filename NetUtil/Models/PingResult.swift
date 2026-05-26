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
        
        // Update buckets
        if rtt < 20 { bucketLow += 1 }
        else if rtt < 50 { bucketMedium += 1 }
        else if rtt < 100 { bucketHigh += 1 }
        else { bucketCritical += 1 }
    }

    mutating func recordTimeout() {
        transmitted += 1
    }
}
