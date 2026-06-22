import SwiftUI
import Charts

struct InterfaceBandwidthCard: View {
    var vm: BandwidthMonitor
    let iface: NetworkInterface

    private var history: [BandwidthSample] { vm.history[iface.name] ?? [] }
    private var current: BandwidthSample? { history.last }
    private var maxVal: Double { max(history.flatMap { [$0.rxBps, $0.txBps] }.max() ?? 1024, 1024) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iface.isUp ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: iface.typeIcon)
                        .foregroundColor(iface.isUp ? .accentColor : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(iface.name)
                        .font(.system(.headline, design: .monospaced))
                    Text(iface.typeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    StatusBadge(isUp: iface.isUp)
                    if let ip = iface.ipAddress {
                        Text(ip)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Interface \(iface.name), Status: \(iface.isUp ? "Active" : "Inactive")")

            // Mini Chart
            Chart {
                ForEach(history) { s in
                    LineMark(x: .value("t", s.timestamp), y: .value("RX", s.rxBps))
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("t", s.timestamp), y: .value("TX", s.txBps))
                        .foregroundStyle(.orange)
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...maxVal * 1.1)
            .drawingGroup() // PERFORMANCE: Optimized for mini sparklines
            .frame(height: 40)
            .accessibilityLabel("Throughput sparkline")
            
            HStack {
                rateMiniDetail(icon: "arrow.down", label: "RX", value: current?.rxBps ?? 0, color: .blue)
                Spacer()
                rateMiniDetail(icon: "arrow.up", label: "TX", value: current?.txBps ?? 0, color: .orange)
            }
            
            Divider().opacity(0.5)
            
            HStack {
                Text("Total Data")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(NetworkMath.formatBytes(current?.totalRx ?? 0)) ↓ · \(NetworkMath.formatBytes(current?.totalTx ?? 0)) ↑")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Total transferred data: \(NetworkMath.formatBytes(current?.totalRx ?? 0)) downloaded, \(NetworkMath.formatBytes(current?.totalTx ?? 0)) uploaded")
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func rateMiniDetail(icon: String, label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.bold())
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(NetworkMath.formatRate(value))
                    .font(.system(.callout, design: .monospaced).weight(.bold))
                    .foregroundColor(value > 0 ? .primary : .secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) Rate")
        .accessibilityValue(NetworkMath.formatRate(value))
    }
}

private struct StatusBadge: View {
    let isUp: Bool
    var body: some View {
        Text(isUp ? "Active" : "Inactive")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isUp ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(isUp ? .green : .secondary)
    }
}
