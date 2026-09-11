import SwiftUI

enum Metrics {
    static let heroNumber: CGFloat = 28
    static let subMetricNumber: CGFloat = 14
    static let chartWindow: Int = 100
    static let healthStripWindow: Int = 60
    static let sparklineWindow: Int = 40
    static let tooltipEstimate: CGFloat = 155
    static let tooltipEstimateNarrow: CGFloat = 130
    static let chartDefaultWidth: CGFloat = 500
    static let settingsColumnWidth: CGFloat = 155

    // Apple HIG Standard Spacing (8pt grid)
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32

    // Apple HIG Standard Corner Radius
    static let cornerRadiusSM: CGFloat = 8
    static let cornerRadiusMD: CGFloat = 10
    static let cornerRadiusLG: CGFloat = 12

    /// Rounds a chart domain ceiling up to a nice number (1 / 2 / 2.5 / 5 × 10ⁿ)
    /// so axis ranges stay stable instead of jittering with live data.
    static func niceCeiling(_ value: Double) -> Double {
        guard value > 0 else { return 1 }
        let exponent = floor(log10(value))
        let fraction = value / pow(10, exponent)
        let niceFraction: Double
        if fraction <= 1 {
            niceFraction = 1
        } else if fraction <= 2 {
            niceFraction = 2
        } else if fraction <= 2.5 {
            niceFraction = 2.5
        } else if fraction <= 5 {
            niceFraction = 5
        } else {
            niceFraction = 10
        }
        return niceFraction * pow(10, exponent)
    }
}

/// Shared stacked-throughput styling: blue = download, orange = upload.
/// Used by the dashboard hero, Bandwidth monitor, and per-interface
/// sparklines so the meaning of each color never changes across the app.
enum ThroughputStyle {
    static let download = LinearGradient(
        colors: [.blue.opacity(0.35), .blue.opacity(0.05)],
        startPoint: .top, endPoint: .bottom)
    static let upload = LinearGradient(
        colors: [.orange.opacity(0.35), .orange.opacity(0.05)],
        startPoint: .top, endPoint: .bottom)

    static let scale: KeyValuePairs<String, LinearGradient> = [
        "Download": download,
        "Upload": upload
    ]
}
