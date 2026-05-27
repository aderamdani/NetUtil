import SwiftUI
import Charts
import Darwin
import Combine

struct BandwidthView: View {
    @StateObject private var vm = BandwidthViewModel()
    @State private var showLearningGuide = false

    private var interfaceNames: [String] {
        vm.interfaces.filter { !$0.isLoopback }.map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. STANDARD HEADER (Fixed Top)
            controlBar
                .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 2. INTERPRETATION HEADER
                    interpretationHeader
                    
                    // 3. STATS BAR
                    statsBar
                    
                    // 4. BANDWIDTH GRID
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TRAFFIC THROUGHPUT")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.secondary)
                            .kerning(1)
                        
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
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showLearningGuide) {
            bandwidthLearningGuideSheet
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // 1. Static Info (Visual Anchor)
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.accentColor)
                Text("Bandwidth Monitor")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
            .frame(width: 250, alignment: .leading)

            // 2. Variable Settings (Centered)
            HStack(spacing: 12) {
                Toggle("Active Only", isOn: $vm.showActiveOnly)
                    .font(.system(size: 11, weight: .bold))
                    .toggleStyle(.checkbox)
                
                Divider().frame(height: 20)
                
                Text("Updated \(vm.lastUpdated.formatted(date: .omitted, time: .standard))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 3. Action Group
            Button { showLearningGuide = true } label: {
                Image(systemName: "book.fill").font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Bandwidth Monitoring Guide")
        }
    }
    
    private var interpretationHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            let active = vm.interfaces.filter { vm.hasTraffic($0.name) }.count
            Image(systemName: active > 0 ? "arrow.up.arrow.down.circle.fill" : "idle.fill")
                .font(.title2)
                .foregroundColor(active > 0 ? .accentColor : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(active > 0 ? "Traffic Detected" : "Network Idle")
                    .font(.headline)
                Text("\(active) adapter\(active == 1 ? "" : "s") are currently transmitting or receiving data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var statsBar: some View {
        let totalRx = vm.history.values.compactMap { $0.last?.rxBps }.reduce(0, +)
        let totalTx = vm.history.values.compactMap { $0.last?.txBps }.reduce(0, +)
        
        return HStack(spacing: 12) {
            StatCard(title: "TOTAL DOWNLOAD", value: formatRate(totalRx), icon: "arrow.down.circle.fill", color: .blue)
            StatCard(title: "TOTAL UPLOAD", value: formatRate(totalTx), icon: "arrow.up.circle.fill", color: .orange)
            StatCard(title: "INTERFACES", value: "\(vm.interfaces.count)", icon: "network")
            Spacer()
        }
    }

    private var ifaceGrid: some View {
        let filtered = vm.interfaces.filter { !$0.isLoopback && (!vm.showActiveOnly || vm.hasTraffic($0.name)) }
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(filtered, id: \.name) { iface in
                BandwidthDetailCard(vm: vm, ifaceName: iface.name, iface: iface)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No network traffic detected.")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private func formatRate(_ bps: Double) -> String {
        if bps < 1024 { return String(format: "%.0f B/s", bps) }
        if bps < 1_048_576 { return String(format: "%.1f KB/s", bps / 1024) }
        return String(format: "%.2f MB/s", bps / 1_048_576)
    }
    
    private var bandwidthLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bandwidth Monitoring Guide").font(.title2.bold())
                    Text("Learn how to track network throughput.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "Traffic RX/TX", icon: "arrow.up.arrow.down") {
                        Text("RX (Download) is data coming into your computer. TX (Upload) is data being sent out. Rates are measured in bits or bytes per second.")
                    }
                    
                    GuideSection(title: "Interface Throughput", icon: "chart.line.uptrend.xyaxis") {
                        Text("Each network adapter has a maximum speed. Monitoring throughput helps identify if an application is saturating your connection.")
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }
}

private struct BandwidthDetailCard: View {
    @ObservedObject var vm: BandwidthViewModel
    let ifaceName: String
    let iface: NetworkInterface

    private var history: [BandwidthSample] { vm.history[ifaceName] ?? [] }
    private var current: BandwidthSample? { history.last }
    private var maxVal: Double {
        let all = history.flatMap { [$0.rxBps, $0.txBps] }
        return max(all.max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: iface.typeIcon)
                    .foregroundColor(iface.isUp ? .accentColor : .secondary)
                    .frame(width: 32, height: 32)
                    .background(iface.isUp ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(ifaceName).font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text(iface.typeName).font(.system(size: 9, weight: .black)).foregroundColor(.secondary)
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
                        AreaMark(x: .value("t", s.timestamp), y: .value("RX", s.rxBps))
                            .foregroundStyle(.blue.opacity(0.1))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("t", s.timestamp), y: .value("RX", s.rxBps))
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)

                        AreaMark(x: .value("t", s.timestamp), y: .value("TX", s.txBps))
                            .foregroundStyle(.orange.opacity(0.1))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("t", s.timestamp), y: .value("TX", s.txBps))
                            .foregroundStyle(.orange)
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 2)) { val in
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text(formatRate(v)).font(.system(size: 8, design: .monospaced))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...maxVal * 1.2)
                .frame(height: 60)
            }
            
            HStack {
                if let total = current {
                    Text("Total RX: \(formatBytes(total.totalRx))").font(.system(size: 9, design: .monospaced))
                    Spacer()
                    Text("Total TX: \(formatBytes(total.totalTx))").font(.system(size: 9, design: .monospaced))
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(18)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
    }

    private func rateMiniLabel(_ dir: String, _ bps: Double?, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(dir).font(.caption.bold()).foregroundColor(color)
            Text(formatRate(bps ?? 0))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(bps ?? 0 > 0 ? color : .secondary)
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

struct BandwidthSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let rxBps: Double
    let txBps: Double
    let totalRx: UInt64
    let totalTx: UInt64
}

@MainActor
class BandwidthViewModel: ObservableObject {
    @Published var interfaces: [NetworkInterface] = []
    @Published var history: [String: [BandwidthSample]] = [:]
    @Published var lastUpdated: Date = Date()
    @Published var showActiveOnly = true

    private var timer: Timer?
    private var prevBytes: [String: (rx: UInt64, tx: UInt64)] = [:]
    private var prevTime: Date = Date()
    private static let historyLimit = 60

    func start() {
        interfaces = NetworkInterfaceFetcher.fetch()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func hasTraffic(_ name: String) -> Bool {
        guard let samples = history[name] else { return false }
        return samples.suffix(5).contains { $0.rxBps > 0 || $0.txBps > 0 }
    }

    private func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(prevTime)
        guard dt > 0 else { return }

        let current = fetchRawBytes()
        lastUpdated = now

        for (name, cur) in current {
            let prev = prevBytes[name] ?? cur
            let rxDelta = cur.rx >= prev.rx ? Double(cur.rx - prev.rx) / dt : 0
            let txDelta = cur.tx >= prev.tx ? Double(cur.tx - prev.tx) / dt : 0

            let sample = BandwidthSample(timestamp: now, rxBps: rxDelta, txBps: txDelta,
                                         totalRx: cur.rx, totalTx: cur.tx)
            history[name, default: []].append(sample)
            if history[name]!.count > Self.historyLimit {
                history[name]!.removeFirst()
            }
        }

        prevBytes = current
        prevTime = now

        let fresh = NetworkInterfaceFetcher.fetch()
        if fresh.map(\.name) != interfaces.map(\.name) { interfaces = fresh }
    }

    private func fetchRawBytes() -> [String: (rx: UInt64, tx: UInt64)] {
        var result: [String: (rx: UInt64, tx: UInt64)] = [:]
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return result }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let ifa = ptr {
            defer { ptr = ifa.pointee.ifa_next }
            guard Int32(ifa.pointee.ifa_addr.pointee.sa_family) == AF_LINK,
                  let data = ifa.pointee.ifa_data else { continue }
            let ifdata = data.assumingMemoryBound(to: if_data.self).pointee
            let name = String(cString: ifa.pointee.ifa_name)
            result[name] = (rx: UInt64(ifdata.ifi_ibytes), tx: UInt64(ifdata.ifi_obytes))
        }
        return result
    }
}
