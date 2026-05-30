import Foundation

enum SpeedTestKind: String, CaseIterable, Identifiable, Codable {
    case speed     = "Speed"
    case browsing  = "Browsing"
    case gaming    = "Gaming"
    case streaming = "Streaming"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .speed:     return "speedometer"
        case .browsing:  return "safari"
        case .gaming:    return "gamecontroller.fill"
        case .streaming: return "play.tv.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .speed:     return "Download, upload, ping, jitter"
        case .browsing:  return "TTFB and full-page load timing"
        case .gaming:    return "Latency, jitter, packet loss"
        case .streaming: return "Sustained throughput tier rating"
        }
    }
}

enum SpeedTestPhase: String {
    case idle      = "Idle"
    case latency   = "Measuring latency..."
    case download  = "Testing download..."
    case upload    = "Testing upload..."
    case browsing  = "Loading sites..."
    case gaming    = "Probing gaming server..."
    case streaming = "Measuring stream stability..."
    case done      = "Complete"
    case failed    = "Failed"
}

struct SpeedTestResult: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let kind: SpeedTestKind
    let provider: String
    var name: String?     // user-editable label
    
    // Speed
    var downloadMbps: Double = 0
    var uploadMbps: Double = 0
    var pingMs: Double = 0
    var jitterMs: Double = 0
    
    // Browsing
    var browsingAvgMs: Double = 0
    var browsingMedianTtfb: Double = 0
    var browsingSites: Int = 0
    
    // Gaming
    var gameMedianMs: Double = 0
    var gameP99Ms: Double = 0
    var gameJitterMs: Double = 0
    var gameLossPct: Double = 0
    
    // Streaming
    var streamAvgMbps: Double = 0
    var streamMinMbps: Double = 0
    var streamTier: String = "—"

    init(timestamp: Date, kind: SpeedTestKind, provider: String) {
        self.timestamp = timestamp
        self.kind = kind
        self.provider = provider
    }
}
