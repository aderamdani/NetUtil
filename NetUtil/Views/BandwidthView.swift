import SwiftUI
import Charts
import Darwin
import Combine

struct BandwidthView: View {
    @EnvironmentObject private var tools: ToolStore
    private var vm: BandwidthMonitor { tools.bandwidth }
    @State private var showLearningGuide = false

    private var interfaceNames: [String] { vm.interfaces.filter { !$0.isLoopback }.map(\.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar.padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    interpretationHeader
                    statsBar.padding(.bottom, 8)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Traffic Throughput")
                        if vm.interfaces.isEmpty {
                            emptyState
                        } else {
                            ifaceGrid
                        }
                    }
                }
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) { bandwidthLearningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis").foregroundColor(.accentColor)
                Text("Bandwidth Monitor").font(.headline)
            }.frame(width: 250, alignment: .leading)

            HStack(spacing: 12) {
                Toggle("Active Only", isOn: Binding(get: { vm.showActiveOnly }, set: { vm.showActiveOnly = $0 })).font(.system(size: 11, weight: .medium)).toggleStyle(.checkbox)
                Divider().frame(height: 20)
                HStack(spacing: 4) {
                    Text("Updated").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    Text(vm.lastUpdated.formatted(date: .omitted, time: .standard)).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                }
            }

            Spacer()

            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View { Text(title).font(.headline).foregroundColor(.primary) }

    private var interpretationHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            let active = vm.interfaces.filter { vm.hasTraffic($0.name) }.count
            Image(systemName: active > 0 ? "arrow.up.arrow.down.circle.fill" : "idle.fill").font(.title2).foregroundColor(active > 0 ? .accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(active > 0 ? "Traffic Detected" : "Network Idle").font(.headline)
                Text("\(active) adapters are actively transmitting or receiving data.").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }.padding(.bottom, 8)
    }

    private var statsBar: some View {
        let totalRx = vm.history.values.compactMap { $0.last?.rxBps }.reduce(0, +)
        let totalTx = vm.history.values.compactMap { $0.last?.txBps }.reduce(0, +)
        return HStack(spacing: 12) {
            StatCard(title: "Total Download", value: formatRate(totalRx), icon: "arrow.down.circle.fill", color: .blue)
            StatCard(title: "Total Upload", value: formatRate(totalTx), icon: "arrow.up.circle.fill", color: .orange)
            StatCard(title: "Interfaces", value: "\(vm.interfaces.count)", icon: "network")
            Spacer()
        }
    }

    private var ifaceGrid: some View {
        let filtered = vm.interfaces.filter { !$0.isLoopback && (!vm.showActiveOnly || vm.hasTraffic($0.name)) }
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(filtered, id: \.name) { iface in BandwidthDetailCard(vm: vm, ifaceName: iface.name, iface: iface) }
        }
    }

    private var emptyState: some View {
        VStack { Spacer(); Text("No network traffic detected.").font(.headline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, minHeight: 150)
    }

    private func formatRate(_ bps: Double) -> String {
        if bps < 1024 { return String(format: "%.0f B/s", bps) }
        if bps < 1_048_576 { return String(format: "%.1f K", bps / 1024) }
        return String(format: "%.2f M", bps / 1_048_576)
    }
    
    private var bandwidthLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Bandwidth Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) { GuideSection(title: "Traffic RX/TX", icon: "arrow.up.arrow.down") { Text("RX (Download), TX (Upload).") } }.padding(24) }
        }.frame(width: 500, height: 600)
    }
}

private struct BandwidthDetailCard: View {
    @ObservedObject var vm: BandwidthMonitor
    let ifaceName: String
    let iface: NetworkInterface

    private var history: [BandwidthSample] { vm.history[ifaceName] ?? [] }
    private var current: BandwidthSample? { history.last }
    private var maxVal: Double { max(history.flatMap { [$0.rxBps, $0.txBps] }.max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: iface.typeIcon).foregroundColor(iface.isUp ? .primary : .secondary).frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ifaceName).font(.system(.headline, design: .monospaced))
                    Text(iface.typeName).font(.caption.weight(.medium)).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    rateMiniLabel("↓", current?.rxBps, .blue)
                    rateMiniLabel("↑", current?.txBps, .orange)
                }
            }

            if history.count > 1 {
                Chart {
                    ForEach(history) { s in
                        AreaMark(x: .value("t", s.timestamp), y: .value("RX", s.rxBps)).foregroundStyle(.blue.opacity(0.1)).interpolationMethod(.catmullRom)
                        LineMark(x: .value("t", s.timestamp), y: .value("RX", s.rxBps)).foregroundStyle(.blue).interpolationMethod(.catmullRom)
                        AreaMark(x: .value("t", s.timestamp), y: .value("TX", s.txBps)).foregroundStyle(.orange.opacity(0.1)).interpolationMethod(.catmullRom)
                        LineMark(x: .value("t", s.timestamp), y: .value("TX", s.txBps)).foregroundStyle(.orange).interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks(values: .automatic(desiredCount: 2)) { val in AxisValueLabel { if let v = val.as(Double.self) { Text(formatRate(v)).font(.system(size: 10, design: .monospaced)) } } } }
                .chartYScale(domain: 0...maxVal * 1.2).frame(height: 50)
            }
            
            HStack {
                if let total = current {
                    Text("Total RX: \(formatBytes(total.totalRx))").font(.system(.caption, design: .monospaced))
                    Spacer()
                    Text("Total TX: \(formatBytes(total.totalTx))").font(.system(.caption, design: .monospaced))
                }
            }.foregroundColor(.secondary)
        }
        .padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func rateMiniLabel(_ dir: String, _ bps: Double?, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(dir).font(.caption.bold()).foregroundColor(color)
            Text(formatRate(bps ?? 0)).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(bps ?? 0 > 0 ? color : .secondary)
        }
    }

    private func formatRate(_ bps: Double) -> String {
        if bps < 1024 { return String(format: "%.0f B/s", bps) }
        if bps < 1_048_576 { return String(format: "%.1f K", bps / 1024) }
        return String(format: "%.2f M", bps / 1_048_576)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1_073_741_824 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        return String(format: "%.2f GB", Double(bytes) / 1_073_741_824)
    }
}

