import SwiftUI
import Charts

/// Hero network-activity chart built on standard Swift Charts patterns:
/// stacked areas split with foregroundStyle(by:), a custom bottom legend
/// (the automatic one is hidden), composed Y axes (labels + grid lines),
/// and cursor selection via chartXSelection with an annotation tooltip.
struct DashboardHeroSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    @State private var selectedTime: Date? = nil

    private var window: [BandwidthSample] {
        Array(tools.bandwidth.totalHistory.suffix(Metrics.sparklineWindow))
    }

    private var yDomainMax: Double {
        let peak = window.map { $0.rxBps + $0.txBps }.max() ?? 0
        let target = peak * 1.25
        if target <= 1024 { return 1024 }
        return Metrics.niceCeiling(target)
    }

    private var selectedSample: BandwidthSample? {
        guard let selectedTime else { return nil }
        return window.min(by: {
            abs($0.timestamp.timeIntervalSince(selectedTime)) < abs($1.timestamp.timeIntervalSince(selectedTime))
        })
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
                    throughputChart
                        .frame(height: 120)
                }

                HStack(spacing: 24) {
                    heroRateMetric(label: "Download", value: tools.bandwidth.totalRxBps, color: .blue)
                    heroRateMetric(label: "Upload", value: tools.bandwidth.totalTxBps, color: .orange)
                    Spacer()
                }
            }
            .padding(Metrics.spacingXL)
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
            if let selected = selectedSample {
                RuleMark(x: .value("Cursor", selected.timestamp))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .top,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        HStack(spacing: 8) {
                            tooltipRate(dir: "↓", value: selected.rxBps, color: .blue)
                            tooltipRate(dir: "↑", value: selected.txBps, color: .orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
            }
        }
        .chartForegroundStyleScale(ThroughputStyle.scale)
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartXSelection(value: $selectedTime)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...yDomainMax)
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
