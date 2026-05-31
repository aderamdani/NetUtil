import Foundation

enum HostStatus: String, Codable {
    case alive = "Alive"
    case unreachable = "Unreachable"
    case scanning = "Scanning"
}

struct SubnetScanResult: Identifiable, Equatable {
    let id = UUID()
    let ip: String
    var hostname: String?
    var status: HostStatus
    var rtt: Double?
    var macAddress: String?
    
    static func == (lhs: SubnetScanResult, rhs: SubnetScanResult) -> Bool {
        lhs.ip == rhs.ip && lhs.status == rhs.status && lhs.rtt == rhs.rtt
    }
}
