import Foundation

/// Parsed output of one `networkQuality -c` run.
struct NetQualityResult {
    let downloadMbps: Double
    let uploadMbps: Double
    /// Responsiveness under working load, in round-trips per minute (RPM).
    let responsivenessRPM: Int
    let baseRttMs: Double?
    let interfaceName: String?
    let endpoint: String?
    let timestamp: Date

    /// RPM bands used for coloring and the verdict label. Documented in the
    /// learning guide: ≥800 feels flawless under load, <300 means noticeable
    /// lag during video calls once the link is busy (bufferbloat).
    var rpmGrade: (label: String, color: String) {
        if responsivenessRPM >= 800 { return ("High", "green") }
        if responsivenessRPM >= 300 { return ("Medium", "orange") }
        return ("Low", "red")
    }
}
