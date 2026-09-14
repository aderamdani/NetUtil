import Foundation

/// IANA IP protocol number ↔ name, plus normalization of transport names.
enum IPProtocol {
    private nonisolated static let names: [Int: String] = [
        1: "ICMP", 6: "TCP", 17: "UDP", 41: "IPv6", 47: "GRE", 50: "ESP",
        51: "AH", 58: "ICMPv6", 89: "OSPF", 103: "PIM", 112: "VRRP", 132: "SCTP"
    ]

    nonisolated static func name(forNumber number: Int) -> String {
        names[number] ?? "IP(\(number))"
    }

    /// Normalizes an lsof/netstat token ("tcp", "6", "TCP") to its canonical
    /// name. Returns nil for unknown tokens.
    nonisolated static func canonical(_ token: String) -> String? {
        let upper = token.uppercased()
        switch upper {
        case "TCP", "UDP", "ICMP", "GRE", "ESP", "AH", "OSPF", "PIM", "VRRP", "SCTP":
            return upper
        case "ICMPV6":
            return "ICMPv6"
        default:
            if let number = Int(token) { return name(forNumber: number) }
            return nil
        }
    }
}
