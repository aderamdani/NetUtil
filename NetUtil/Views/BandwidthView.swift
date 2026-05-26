import SwiftUI
import Charts
import Darwin
import Combine

struct BandwidthView: View {
    @StateObject private var vm = BandwidthViewModel()
    @State private var selectedIface: String?

    private var interfaceNames: [String] {
        vm.interfaces.filter { !$0.isLoopback }.map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar
            if vm.interfaces.isEmpty {
                emptyState
            } else {
                ifaceGrid
            }
        }
        .padding()
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }

    private var toolbar: some View {
        HStack {
            Text("Updated \(vm.lastUpdated.formatted(date: .omitted, time: .standard))")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            Spacer()
            Toggle("Active only", isOn: $vm.showActiveOnly)
                .toggleStyle(.checkbox)
                .font(.caption)
        }
    }

    private var ifaceGrid: some View {
        let filtered = vm.interfaces.filter { !$0.isLoopback && (!vm.showActiveOnly || vm.hasTraffic($0.name)) }
        return ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(filtered, id: \.name) { iface in
                    BandwidthCard(vm: vm, ifaceName: iface.name, iface: iface)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "network")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No interfaces found")
                .foregroundColor(.secondary)
                .font(.callout)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }
}

private struct BandwidthCard: View {
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: iface.typeIcon)
                    .foregroundColor(iface.isUp ? .accentColor : .secondary)
                Text(ifaceName)
                    .font(.system(.body, design: .monospaced).bold())
                Text(iface.typeName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(.quaternaryLabelColor))
                    .cornerRadius(4)
                Spacer()
                Circle()
                    .fill(iface.isUp ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
            }

            HStack(spacing: 16) {
                rateLabel("↓", current?.rxBps, .blue)
                rateLabel("↑", current?.txBps, .orange)
                Spacer()
                if let total = current {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("RX \(formatBytes(total.totalRx))")
                        Text("TX \(formatBytes(total.totalTx))")
                    }
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                }
            }

            if history.count > 1 {
                Chart {
                    ForEach(history) { s in
                        LineMark(x: .value("t", s.timestamp), y: .value("RX", s.rxBps),
                                 series: .value("dir", "RX"))
                            .foregroundStyle(.blue.opacity(0.8))
                        LineMark(x: .value("t", s.timestamp), y: .value("TX", s.txBps),
                                 series: .value("dir", "TX"))
                            .foregroundStyle(.orange.opacity(0.8))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { val in
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text(formatRate(v)).font(.system(.caption2, design: .monospaced))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...maxVal * 1.2)
                .frame(height: 80)
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separatorColor), lineWidth: 0.5))
    }

    private func rateLabel(_ dir: String, _ bps: Double?, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(dir).font(.caption.bold()).foregroundColor(color)
            Text(formatRate(bps ?? 0))
                .font(.system(.body, design: .monospaced).bold())
                .foregroundColor(bps ?? 0 > 0 ? color : .secondary)
        }
    }

    private func formatRate(_ bps: Double) -> String {
        if bps < 1024 { return String(format: "%.0f B/s", bps) }
        if bps < 1_048_576 { return String(format: "%.1f KB/s", bps / 1024) }
        return String(format: "%.2f MB/s", bps / 1_048_576)
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
