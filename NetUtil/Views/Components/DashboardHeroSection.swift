import SwiftUI
import Charts

struct DashboardHeroSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    @State private var isHovered = false
    @State private var showDetails = false

    var body: some View {
        Button { selection = .bandwidth } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .symbolEffect(.pulse, options: .repeating, value: tools.bandwidth.totalRxBps > 0 || tools.bandwidth.totalTxBps > 0)
                            Text("Network Activity")
                                .font(.headline)
                        }
                        Text(tools.currentConnectionName.isEmpty ? "No active connection" : tools.currentConnectionName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if isHovered || showDetails {
                        VStack(spacing: 12) {
                            HStack(spacing: 20) {
                                InteractiveRatePill(
                                    label: "Download",
                                    value: tools.bandwidth.totalRxBps,
                                    color: .blue,
                                    icon: "arrow.down.circle.fill"
                                )
                                InteractiveRatePill(
                                    label: "Upload",
                                    value: tools.bandwidth.totalTxBps,
                                    color: .orange,
                                    icon: "arrow.up.circle.fill"
                                )
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                    } else {
                        HStack(spacing: 16) {
                            heroRateMetric(label: "↓", value: tools.bandwidth.totalRxBps, color: .blue)
                            heroRateMetric(label: "↑", value: tools.bandwidth.totalTxBps, color: .orange)
                        }
                    }
                }
                
                Chart {
                    ForEach(tools.bandwidth.totalHistory.suffix(Metrics.sparklineWindow)) { s in
                        AreaMark(x: .value("Time", s.timestamp), y: .value("Download", s.rxBps))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue.opacity(0.15), .blue.opacity(0.0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Time", s.timestamp), y: .value("Download", s.rxBps))
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .interpolationMethod(.catmullRom)

                        LineMark(x: .value("Time", s.timestamp), y: .value("Upload", s.txBps))
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartPlotStyle { plot in
                    plot.frame(height: 80).background(.clear)
                }
                .drawingGroup()
                .frame(height: 80)
                .overlay(alignment: .bottomTrailing) {
                    if isHovered {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Peak ↓ \(NetworkMath.formatRate(tools.bandwidth.peakRx))")
                            Text("Peak ↑ \(NetworkMath.formatRate(tools.bandwidth.peakTx))")
                        }
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .padding(4)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .accessibilityLabel("Real-time network throughput chart. \(formatAccessibilitySummary())")

                if isHovered {
                    HStack(spacing: 16) {
                        Label("Click for detailed bandwidth monitor", systemImage: "chart.bar.xaxis")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        if tools.bandwidth.totalRxBps > 0 || tools.bandwidth.totalTxBps > 0 {
                            Label("Active traffic detected", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isHovered ? Color.blue.opacity(0.3) : Color(.separatorColor).opacity(0.1),
                                lineWidth: isHovered ? 1.5 : 0.5
                            )
                    )
            )
            .scaleEffect(isHovered ? 1.005 : 1.0)
            .shadow(
                color: isHovered ? Color.blue.opacity(0.15) : .clear,
                radius: isHovered ? 16 : 0,
                x: 0, y: isHovered ? 6 : 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isHovered = hovering
                showDetails = hovering
            }
        }
        .accessibilityLabel("Network Activity Overview. Tap to open Bandwidth Monitor.")
    }

    private func heroRateMetric(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            Text(NetworkMath.formatRate(value))
                .font(.title3.monospaced().weight(.bold))
                .foregroundColor(color)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) Rate")
        .accessibilityValue(NetworkMath.formatRate(value))
    }

    private func formatAccessibilitySummary() -> String {
        let rx = NetworkMath.formatRate(tools.bandwidth.totalRxBps)
        let tx = NetworkMath.formatRate(tools.bandwidth.totalTxBps)
        return "Current download \(rx), upload \(tx)."
    }
}

struct InteractiveRatePill: View {
    let label: String
    let value: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
            }
            Text(NetworkMath.formatRate(value))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }
}