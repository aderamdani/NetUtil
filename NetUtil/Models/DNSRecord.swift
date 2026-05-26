import Foundation

struct DNSRecord: Identifiable {
    let id = UUID()
    let name: String
    let ttl: Int
    let type: String
    let value: String
}

struct DNSResult {
    let server: String
    let queryTimeMs: Int?
    let records: [DNSRecord]
    let timestamp: Date
}

enum DNSRecordType: String, CaseIterable {
    case a    = "A"
    case aaaa = "AAAA"
    case mx   = "MX"
    case ns   = "NS"
    case cname = "CNAME"
    case txt  = "TXT"
    case ptr  = "PTR"
    case soa  = "SOA"
    case any  = "ANY"
}

enum DNSServer: String, CaseIterable, Identifiable {
    case system     = "System"
    case google     = "Google (8.8.8.8)"
    case cloudflare = "Cloudflare (1.1.1.1)"
    case quad9      = "Quad9 (9.9.9.9)"

    var id: String { rawValue }

    var address: String? {
        switch self {
        case .system:     nil
        case .google:     "8.8.8.8"
        case .cloudflare: "1.1.1.1"
        case .quad9:      "9.9.9.9"
        }
    }
}
