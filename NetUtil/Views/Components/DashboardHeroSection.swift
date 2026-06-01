import SwiftUI
import Charts

struct DashboardHeroSection: View {
    @Environment(ToolStore.self) private var tools
    @Binding var selection: Tool?

    var body: some View {
        Button { selection = .bandwidth } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Network Activity")
                            .font(.headline)
                        Text("Live aggregate throughput")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 16) {
                        heroRateMetric(label: "Download", value: tools.bandwidth.totalRxBps, color: .blue)
                        heroRateMetric(label: "Upload", value: tools.bandwidth.totalTxBps, color: .orange)
                    }
                }
                
                Chart {
                    ForEach(tools.bandwidth.totalHistory.suffix(100)) { s in
                        AreaMark(x: .value("t", s.timestamp), y: .value("RX", s.rxBps))
                            .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.1), .blue.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("t", s.timestamp), y: .value("RX", s.rxBps))
                            .foregroundStyle(.blue)

                        LineMark(x: .value("t", s.timestamp), y: .value("TX", s.txBps))
                            .foregroundStyle(.orange)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .drawingGroup() 
                .frame(height: 80)
                .accessibilityLabel("Real-time network throughput hero chart")
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Network Activity Overview. Tap to open Bandwidth Monitor.")
    }

    private func heroRateMetric(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(label).font(.caption2.weight(.bold)).foregroundColor(.secondary)
            Text(NetworkMath.formatRate(value))
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundColor(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) Rate")
        .accessibilityValue(NetworkMath.formatRate(value))
    }
}
