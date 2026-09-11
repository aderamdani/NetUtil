import SwiftUI
import Charts

/// Hero network-activity chart: download + upload as a stacked area so the
/// total shape stays readable at a glance. The header rates double as the
/// legend (matching colors); hovering any point reveals exact values.
struct DashboardHeroSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    @State private var hoveredSample: BandwidthSample? = nil
    @State private var hoverLocation: CGPoint = .zero
    @State private var chartWidth: CGFloat = Metrics.chartDefaultWidth

    private var window: [BandwidthSample] {
        Array(tools.bandwidth.totalHistory.suffix(Metrics.sparklineWindow))
    }

    private var maxTotal: Double {
        let peak = window.map { $0.rxBps + $0.txBps }.max() ?? 0
        return max(peak * 1.25, 1024)
    }

    /// Legend entries with no traffic are hidden — except when fully idle,
    /// where both zero values honestly report the idle state.
    private var showRx: Bool {
        tools.bandwidth.totalRxBps > 0 || tools.bandwidth.totalTxBps == 0
    }

    private var showTx: Bool {
        tools.bandwidth.totalTxBps > 0 || tools.bandwidth.totalRxBps == 0
    }

    var body: some View {
        Button { selection = .bandwidth } label: {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Network Activity")
                        .font(.headline)
                    Text("Live aggregate throughput")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if window.isEmpty {
                    Text("Collecting samples…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ZStack(alignment: .topLeading) {
                        throughputChart
                            .frame(height: 120)
                            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { newWidth in
                                if abs(chartWidth - newWidth) > 1 { chartWidth = newWidth }
                            }

                        if let sample = hoveredSample {
                            let tooltipEst: CGFloat = Metrics.tooltipEstimate
                            let clampedX = max(0, min(hoverLocation.x - tooltipEst / 2, chartWidth - tooltipEst))
                            HStack(spacing: 8) {
                                tooltipRate(dir: "↓", value: sample.rxBps, color: .blue)
                                tooltipRate(dir: "↑", value: sample.txBps, color: .orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .offset(x: clampedX, y: 4)
                            .allowsHitTesting(false)
                        }
                    }
                }

                HStack(spacing: 24) {
                    if showRx {
                        heroRateMetric(label: "Download", value: tools.bandwidth.totalRxBps, color: .blue)
                    }
                    if showTx {
                        heroRateMetric(label: "Upload", value: tools.bandwidth.totalTxBps, color: .orange)
                    }
                    Spacer()
                }
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Network Activity Overview. Download \(NetworkMath.formatRate(tools.bandwidth.totalRxBps)), upload \(NetworkMath.formatRate(tools.bandwidth.totalTxBps)). Tap to open Bandwidth Monitor.")
    }

    private var throughputChart: some View {
        Chart {
            ForEach(window) { s in
                AreaMark(
                    x: .value("Time", s.timestamp),
                    y: .value("Rate", s.rxBps),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Direction", "Download"))
                .interpolationMethod(.monotone)
                AreaMark(
                    x: .value("Time", s.timestamp),
                    y: .value("Rate", s.txBps),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Direction", "Upload"))
                .interpolationMethod(.monotone)
            }
            if let hovered = hoveredSample {
                RuleMark(x: .value("Cursor", hovered.timestamp))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartForegroundStyleScale([
            "Download": LinearGradient(colors: [.blue.opacity(0.35), .blue.opacity(0.05)], startPoint: .top, endPoint: .bottom),
            "Upload": LinearGradient(colors: [.orange.opacity(0.35), .orange.opacity(0.05)], startPoint: .top, endPoint: .bottom)
        ])
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(verbatim: NetworkMath.formatRate(v))
                            .font(.caption2.monospaced())
                    }
                }
            }
        }
        .chartYScale(domain: 0...maxTotal)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoverLocation = location
                            let plotOriginX = proxy.plotFrame.map { geo[$0].minX } ?? 0
                            if let date: Date = proxy.value(atX: location.x - plotOriginX),
                               let match = window.min(by: {
                                   abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
                               }) {
                                hoveredSample = match
                            }
                        case .ended:
                            hoveredSample = nil
                        }
                    }
            }
        }
        .drawingGroup()
        .accessibilityLabel("Stacked throughput chart of download and upload rates")
    }

    private func heroRateMetric(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            }
            Text(NetworkMath.formatRate(value))
                .font(.title3.monospaced().weight(.bold))
                .foregroundColor(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) Rate")
        .accessibilityValue(NetworkMath.formatRate(value))
    }

    private func tooltipRate(dir: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(dir).font(.caption.bold()).foregroundColor(color)
            Text(NetworkMath.formatRate(value))
                .font(.caption.monospaced().weight(.semibold))
                .foregroundColor(color)
        }
    }
}
