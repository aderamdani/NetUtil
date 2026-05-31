import Foundation
import Network

struct BonjourService: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let type: String
    let domain: String
    var host: String?
    var port: Int?
    var addresses: [String] = []
    var txtRecords: [String: String] = [:]
    let timestamp = Date()
    
    var resolvedAddress: String {
        if let host = host, let port = port {
            return "\(host):\(port)"
        } else if !addresses.isEmpty {
            return addresses.joined(separator: ", ")
        }
        return "Resolving..."
    }
}
