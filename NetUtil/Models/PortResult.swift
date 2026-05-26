import Foundation

enum PortStatus {
    case open, closed, filtered

    var label: String {
        switch self {
        case .open:     "Open"
        case .closed:   "Closed"
        case .filtered: "Filtered"
        }
    }
}

struct PortResult: Identifiable {
    let id = UUID()
    let port: Int
    let status: PortStatus
    let service: String?
    let responseMs: Double?
}

enum PortPreset: String, CaseIterable, Identifiable {
    case web      = "Web"
    case mail     = "Mail"
    case database = "Database"
    case remote   = "Remote"
    case common   = "Common"
    case custom   = "Custom"

    var id: String { rawValue }

    var ports: [Int]? {
        switch self {
        case .web:      return [80, 443, 8080, 8443, 8000, 3000, 5000, 4443]
        case .mail:     return [25, 465, 587, 110, 995, 143, 993]
        case .database: return [3306, 5432, 1433, 1521, 27017, 6379, 5984, 9200]
        case .remote:   return [22, 23, 3389, 5900, 5901, 5902, 2222, 6000]
        case .common:   return [21,22,23,25,53,80,110,111,135,139,143,
                                443,445,993,995,1080,1723,3306,3389,
                                5900,8080,8443,8888,9090,9200]
        case .custom:   return nil
        }
    }
}

// Well-known port → service name
let wellKnownPorts: [Int: String] = [
    21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP", 53: "DNS",
    80: "HTTP", 110: "POP3", 111: "RPC", 135: "MSRPC", 139: "NetBIOS",
    143: "IMAP", 443: "HTTPS", 445: "SMB", 465: "SMTPS", 587: "SMTP",
    993: "IMAPS", 995: "POP3S", 1080: "SOCKS", 1433: "MSSQL",
    1521: "Oracle", 1723: "PPTP", 2222: "SSH-Alt", 3000: "Dev",
    3306: "MySQL", 3389: "RDP", 4443: "HTTPS-Alt", 5000: "Dev",
    5432: "PostgreSQL", 5900: "VNC", 5901: "VNC-1", 5902: "VNC-2",
    5984: "CouchDB", 6000: "X11", 6379: "Redis", 8000: "Dev",
    8080: "HTTP-Alt", 8443: "HTTPS-Alt", 8888: "Dev", 9090: "Admin",
    9200: "Elasticsearch", 27017: "MongoDB"
]
