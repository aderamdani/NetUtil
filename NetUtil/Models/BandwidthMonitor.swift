import Foundation
import Darwin
import Combine

struct BandwidthSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let rxBps: Double
    let txBps: Double
    let totalRx: UInt64
    let totalTx: UInt64
}

@MainActor
class BandwidthMonitor: ObservableObject {
    @Published var interfaces: [NetworkInterface] = []
    @Published var history: [String: [BandwidthSample]] = [:]
    @Published var lastUpdated: Date = Date()
    @Published var showActiveOnly = true

    /// Aggregate samples across all non-loopback adapters — one per second.
    @Published var totalHistory: [BandwidthSample] = []
    @Published var peakRx: Double = 0
    @Published var peakTx: Double = 0
    @Published var isPaused = false

    private var timer: Timer?
    private var prevBytes: [String: (rx: UInt64, tx: UInt64)] = [:]
    private var prevTime: Date = Date()
    private static let historyLimit = 60
    private static let totalHistoryLimit = 600 // 10 min

    /// Called every tick with raw byte deltas (non-loopback only).
    var onAggregateDelta: ((UInt64, UInt64) -> Void)?

    /// Aggregate current rates (sum across active non-loopback adapters).
    var totalRxBps: Double { totalHistory.last?.rxBps ?? 0 }
    var totalTxBps: Double { totalHistory.last?.txBps ?? 0 }

    func start() {
        guard timer == nil else { return }
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

    func resetPeaks() {
        peakRx = 0
        peakTx = 0
    }

    private func tick() {
        guard !isPaused else {
            prevTime = Date() // Reset baseline
            return
        }
        
        let now = Date()
        let dt = now.timeIntervalSince(prevTime)
        guard dt > 0 else { return }

        let current = fetchRawBytes()
        lastUpdated = now

        var aggRx: Double = 0
        var aggTx: Double = 0
        var totalRxBytes: UInt64 = 0
        var totalTxBytes: UInt64 = 0
        var aggRxRaw: UInt64 = 0
        var aggTxRaw: UInt64 = 0

        for (name, cur) in current {
            let prev = prevBytes[name] ?? cur
            let rxDeltaRaw = cur.rx >= prev.rx ? cur.rx - prev.rx : 0
            let txDeltaRaw = cur.tx >= prev.tx ? cur.tx - prev.tx : 0
            let rxDelta = Double(rxDeltaRaw) / dt
            let txDelta = Double(txDeltaRaw) / dt

            let sample = BandwidthSample(timestamp: now, rxBps: rxDelta, txBps: txDelta, totalRx: cur.rx, totalTx: cur.tx)
            history[name, default: []].append(sample)
            if history[name]!.count > Self.historyLimit { history[name]!.removeFirst() }

            // Skip loopback for aggregate totals
            if !name.hasPrefix("lo") {
                aggRx += rxDelta
                aggTx += txDelta
                totalRxBytes &+= cur.rx
                totalTxBytes &+= cur.tx
                aggRxRaw &+= rxDeltaRaw
                aggTxRaw &+= txDeltaRaw
            }
        }

        if !prevBytes.isEmpty {
            onAggregateDelta?(aggRxRaw, aggTxRaw)
        }

        // Persist aggregate sample for menu bar + statistics history
        if prevTime != now {
            let agg = BandwidthSample(timestamp: now, rxBps: aggRx, txBps: aggTx,
                                      totalRx: totalRxBytes, totalTx: totalTxBytes)
            totalHistory.append(agg)
            if totalHistory.count > Self.totalHistoryLimit { totalHistory.removeFirst() }
            
            // Update peaks
            if aggRx > peakRx { peakRx = aggRx }
            if aggTx > peakTx { peakTx = aggTx }
            
            UserDefaults.standard.set(aggRx, forKey: "menuBarCurrentRxBps")
            UserDefaults.standard.set(aggTx, forKey: "menuBarCurrentTxBps")
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
            guard Int32(ifa.pointee.ifa_addr.pointee.sa_family) == AF_LINK, let data = ifa.pointee.ifa_data else { continue }
            let ifdata = data.assumingMemoryBound(to: if_data.self).pointee
            let name = String(cString: ifa.pointee.ifa_name)
            result[name] = (rx: UInt64(ifdata.ifi_ibytes), tx: UInt64(ifdata.ifi_obytes))
        }
        return result
    }
}
