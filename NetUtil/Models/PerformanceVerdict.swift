import Foundation

/// Plain-language verdicts for network performance metrics.
/// Designed for non-technical users to understand what their speeds/latency mean.
enum PerformanceVerdict {

    // MARK: - Speed Test Verdicts

    struct SpeedVerdict {
        let downloadMbps: Double
        let uploadMbps: Double
        let pingMs: Double
        let jitterMs: Double

        /// Human-readable summary of what this connection can handle.
        var summary: String {
            let activities = supportedActivities
            if activities.isEmpty {
                return "Connection too slow for most modern tasks. Consider troubleshooting or upgrading."
            }
            return "Suitable for: \(activities.joined(separator: ", "))"
        }

        /// List of activities the connection supports well.
        var supportedActivities: [String] {
            var acts: [String] = []

            // Streaming thresholds (per stream)
            if downloadMbps >= 25 { acts.append("4K streaming") }
            else if downloadMbps >= 15 { acts.append("4K streaming (single)") }
            else if downloadMbps >= 5 { acts.append("1080p streaming") }
            else if downloadMbps >= 3 { acts.append("720p streaming") }

            // Video calls
            if downloadMbps >= 3 && uploadMbps >= 3 && pingMs < 150 && jitterMs < 30 {
                acts.append("HD video calls (Zoom/Teams)")
            } else if downloadMbps >= 1.5 && uploadMbps >= 1.5 && pingMs < 200 {
                acts.append("SD video calls")
            }

            // Gaming
            if pingMs < 50 && jitterMs < 20 && downloadMbps >= 3 && uploadMbps >= 1 {
                acts.append("Competitive gaming")
            } else if pingMs < 100 && jitterMs < 50 {
                acts.append("Casual gaming")
            }

            // Remote desktop / VPN
            if downloadMbps >= 10 && uploadMbps >= 5 && pingMs < 100 {
                acts.append("Remote desktop / VPN")
            }

            // Large file transfers
            if downloadMbps >= 50 { acts.append("Fast downloads") }
            else if downloadMbps >= 10 { acts.append("Moderate downloads") }

            // Web browsing (always works if > 0)
            if downloadMbps > 0 { acts.append("Web browsing") }

            return acts
        }

        /// Color-coded overall rating.
        var rating: (label: String, color: String) {
            if downloadMbps >= 100 && uploadMbps >= 20 && pingMs < 30 { return ("Excellent", "green") }
            if downloadMbps >= 50 && uploadMbps >= 10 && pingMs < 50 { return ("Good", "green") }
            if downloadMbps >= 25 && uploadMbps >= 5 && pingMs < 100 { return ("Fair", "orange") }
            if downloadMbps >= 5 && uploadMbps >= 1 && pingMs < 200 { return ("Limited", "orange") }
            return ("Poor", "red")
        }

        /// Detailed breakdown for UI.
        var details: [String] {
            var d: [String] = []
            d.append("Download: \(String(format: "%.1f", downloadMbps)) Mbps — \(downloadQuality)")
            d.append("Upload: \(String(format: "%.1f", uploadMbps)) Mbps — \(uploadQuality)")
            d.append("Ping: \(String(format: "%.0f", pingMs)) ms — \(pingQuality)")
            d.append("Jitter: \(String(format: "%.1f", jitterMs)) ms — \(jitterQuality)")
            return d
        }

        private var downloadQuality: String {
            switch downloadMbps {
            case 100...: return "Excellent"
            case 50..<100: return "Very Good"
            case 25..<50: return "Good"
            case 10..<25: return "Fair"
            case 5..<10: return "Limited"
            case 0..<5: return "Poor"
            default: return "No connection"
            }
        }

        private var uploadQuality: String {
            switch uploadMbps {
            case 50...: return "Excellent"
            case 20..<50: return "Very Good"
            case 10..<20: return "Good"
            case 5..<10: return "Fair"
            case 1..<5: return "Limited"
            case 0..<1: return "Poor"
            default: return "No connection"
            }
        }

        private var pingQuality: String {
            switch pingMs {
            case 0..<20: return "Excellent"
            case 20..<50: return "Good"
            case 50..<100: return "Fair"
            case 100..<200: return "High"
            default: return "Very High"
            }
        }

        private var jitterQuality: String {
            switch jitterMs {
            case 0..<10: return "Stable"
            case 10..<30: return "Acceptable"
            case 30..<50: return "Variable"
            default: return "Unstable"
            }
        }
    }

    // MARK: - Network Quality (RPM) Verdicts

    struct RPMVerdict {
        let rpm: Int
        let downloadMbps: Double
        let uploadMbps: Double
        let baseRttMs: Double?

        var grade: (label: String, color: String) {
            if rpm >= 800 { return ("High", "green") }
            if rpm >= 300 { return ("Medium", "orange") }
            return ("Low", "red")
        }

        /// What this RPM means in practice.
        var explanation: String {
            switch grade.label {
            case "High":
                return "Connection stays responsive under heavy load. Video calls, gaming, and streaming remain smooth even when downloading large files."
            case "Medium":
                return "Noticeable lag during heavy usage. Video calls may stutter when someone else downloads. Gaming ping spikes under load."
            default:
                return "Significant bufferbloat. Connection becomes sluggish under load — video calls freeze, gaming unplayable, web pages load slowly while downloading."
            }
        }

        /// Practical recommendations.
        var recommendations: [String] {
            switch grade.label {
            case "High":
                return ["No action needed — your network handles load well"]
            case "Medium":
                return ["Enable QoS on router for video calls/gaming",
                        "Limit large downloads during important calls",
                        "Consider router with SQM (Smart Queue Management)"]
            default:
                return ["Enable QoS / SQM on router (strongly recommended)",
                        "Avoid simultaneous heavy downloads during calls/gaming",
                        "Test with Ethernet to rule out Wi-Fi congestion",
                        "Contact ISP if persistent — may indicate line issues"]
            }
        }

        /// Throughput suitability (same as SpeedVerdict but simpler).
        var throughputSummary: String {
            var result = ""
            if downloadMbps >= 25 { result += "4K streaming, " }
            else if downloadMbps >= 5 { result += "1080p streaming, " }
            else if downloadMbps >= 3 { result += "720p streaming, " }
            if downloadMbps >= 10 { result += "fast downloads, " }
            if uploadMbps >= 5 { result += "HD video calls, " }
            else if uploadMbps >= 1.5 { result += "SD video calls, " }
            if rpm >= 800 { result += "gaming & real-time apps smooth under load" }
            else if rpm >= 300 { result += "gaming OK if network not busy" }
            else { result += "gaming/calls degrade under load" }
            return result
        }
    }

    // MARK: - HTTP Latency Verdicts

    struct HTTPLatencyVerdict {
        let totalMs: Double
        let ttfbMs: Double?
        let statusCode: Int?
        let phases: [String: Double] // phase -> durationMs

        /// Overall rating based on TTFB + total latency.
        var rating: (label: String, color: String) {
            let ttfb = ttfbMs ?? totalMs
            if ttfb < 100 && totalMs < 300 { return ("Excellent", "green") }
            if ttfb < 200 && totalMs < 500 { return ("Good", "green") }
            if ttfb < 500 && totalMs < 1000 { return ("Fair", "orange") }
            if ttfb < 1000 && totalMs < 2000 { return ("Slow", "orange") }
            return ("Very Slow", "red")
        }

        /// What this latency means for user experience.
        var explanation: String {
            switch rating.label {
            case "Excellent":
                return "Near-instant page loads. Excellent for browsing, SPAs, and API-dependent apps."
            case "Good":
                return "Fast, snappy experience. Most users won't notice delays."
            case "Fair":
                return "Perceptible delay on complex pages. TTFB may impact SEO and conversions."
            case "Slow":
                return "Noticeable wait for content. Consider CDN, caching, or server optimization."
            default:
                return "Severely degraded. Users likely abandoning. Check server health, DB queries, network path."
            }
        }

        /// Phase-specific insights.
        var phaseInsights: [String] {
            var insights: [String] = []
            if let dns = phases["DNS"], dns > 100 { insights.append("DNS lookup slow (\(Int(dns)) ms) — try faster resolver (1.1.1.1, 8.8.8.8)") }
            if let tcp = phases["TCP"], tcp > 100 { insights.append("TCP connect slow (\(Int(tcp)) ms) — check network path / firewall") }
            if let tls = phases["TLS"], tls > 200 { insights.append("TLS handshake slow (\(Int(tls)) ms) — consider session resumption / CDN") }
            if let ttfb = phases["TTFB"], ttfb > 500 { insights.append("Server response slow (\(Int(ttfb)) ms) — backend / DB bottleneck") }
            if let dl = phases["Download"], dl > 500 { insights.append("Content download slow (\(Int(dl)) ms) — large payload or bandwidth limit") }
            if insights.isEmpty { insights.append("All phases within healthy ranges") }
            return insights
        }
    }
}