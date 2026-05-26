import Foundation

enum HTTPPhase: String, CaseIterable {
    case dns      = "DNS"
    case tcp      = "TCP"
    case tls      = "TLS"
    case request  = "Request"
    case ttfb     = "TTFB"
    case download = "Download"

    var color: String {
        switch self {
        case .dns:      return "teal"
        case .tcp:      return "blue"
        case .tls:      return "purple"
        case .request:  return "orange"
        case .ttfb:     return "yellow"
        case .download: return "green"
        }
    }
}

struct HTTPPhaseTiming: Identifiable {
    let id = UUID()
    let phase: HTTPPhase
    let startMs: Double
    let durationMs: Double
    var endMs: Double { startMs + durationMs }
}

struct HTTPLatencyResult: Identifiable {
    let id = UUID()
    let url: String
    let method: String
    let statusCode: Int?
    let totalMs: Double
    let phases: [HTTPPhaseTiming]
    let bodyBytes: Int64?
    let redirectCount: Int
    let timestamp: Date
}
