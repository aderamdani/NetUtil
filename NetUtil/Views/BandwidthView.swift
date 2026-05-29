import SwiftUI
import Charts
import Darwin
import Combine

struct BandwidthView: View {
    @EnvironmentObject private var tools: ToolStore
    private var vm: BandwidthMonitor { tools.bandwidth }
    @State private var showLearningGuide = false
    @State private var selectedPoint: Date? = nil

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
                    aggregateSection
                    
                    statsBar
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Network Interfaces")
                                .font(.headline)
                            Spacer()
                            Text("\(vm.interfaces.count) Total")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                        
                        if vm.interfaces.isEmpty {
                            emptyState
                        } else {
                            ifaceGrid
                        }
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Bandwidth Monitor") }
    }

    // MARK: - Components

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Bandwidth Monitor")
                        .font(.headline)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Toggle("Active Only", isOn: Binding(get: { vm.showActiveOnly }, set: { vm.showActiveOnly = $0 }))
                        .toggleStyle(.checkbox)
                        .font(.subheadline)
                    
                    Divider().frame(height: 16)
                    
                    Button {
                        vm.isPaused.toggle()
                    } label: {
                        Label(vm.isPaused ? "Resume" : "Pause", systemImage: vm.isPaused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.borderless)
                    
                    Button {
                        vm.resetPeaks()
                    } label: {
                        Label("Reset Peaks", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    
                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            Divider()
        }
    }

    private var aggregateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Throughput")
                        .font(.headline)
                    Text("Real-time aggregate across all active adapters")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    rateIndicator(label: "Download", value: vm.totalRxBps, color: .blue)
                    rateIndicator(label: "Upload", value: vm.totalTxBps, color: .orange)
                }
            }

            // Large Aggregate Chart
            VStack(spacing: 0) {
                Chart {
                    ForEach(vm.totalHistory) { s in
                        AreaMark(x: .value("Time", s.timestamp), y: .value("Download", s.rxBps))
                            .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.3), .blue.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Time", s.timestamp), y: .value("Download", s.rxBps))
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)

                        AreaMark(x: .value("Time", s.timestamp), y: .value("Upload", s.txBps))
                            .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.2), .orange.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Time", s.timestamp), y: .value("Upload", s.txBps))
                            .foregroundStyle(.orange)
                            .interpolationMethod(.catmullRom)
                        
                        if let selectedPoint, Calendar.current.isDate(s.timestamp, equalTo: selectedPoint, toGranularity: .second) {
                            RuleMark(x: .value("Selected", s.timestamp))
                                .foregroundStyle(Color.secondary.opacity(0.3))
                                .offset(y: 0)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .minute, count: 2)) { value in
                        AxisValueLabel(format: .dateTime.minute().second())
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(NetworkMath.formatRate(v))
                                    .font(.system(size: 10, design: .monospaced))
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    selectedPoint = proxy.value(atX: location.x)
                                case .ended:
                                    selectedPoint = nil
                                }
                            }
                    }
                }
                .frame(height: 180)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "Peak Download", value: NetworkMath.formatRate(vm.peakRx), icon: "arrow.down.to.line", color: .blue)
            StatCard(title: "Peak Upload", value: NetworkMath.formatRate(vm.peakTx), icon: "arrow.up.to.line", color: .orange)
            StatCard(title: "Session Total", value: NetworkMath.formatBytes(vm.totalHistory.last?.totalRx ?? 0), icon: "chart.pie.fill")
            StatCard(title: "Status", value: vm.isPaused ? "Paused" : "Monitoring", icon: vm.isPaused ? "pause.circle.fill" : "record.circle.fill", color: vm.isPaused ? .secondary : .green)
        }
    }

    private var ifaceGrid: some View {
        let filtered = vm.interfaces.filter { !$0.isLoopback && (!vm.showActiveOnly || vm.hasTraffic($0.name)) }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
            ForEach(filtered, id: \.name) { iface in
                BandwidthInterfaceCard(vm: vm, iface: iface)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No Active Traffic Detected")
                .font(.headline)
            Text("Enable 'Show All' or connect to a network to see adapters.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func rateIndicator(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
            Text(NetworkMath.formatRate(value))
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Interface Card

struct BandwidthInterfaceCard: View {
    @ObservedObject var vm: BandwidthMonitor
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
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }

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
            .frame(height: 40)
            
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
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
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
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(value > 0 ? .primary : .secondary)
            }
        }
    }
}

private struct StatusBadge: View {
    let isUp: Bool
    var body: some View {
        Text(isUp ? "Active" : "Inactive")
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isUp ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
            .foregroundColor(isUp ? .green : .secondary)
            .cornerRadius(4)
    }
}
