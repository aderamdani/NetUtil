import Foundation
import Observation

@Observable
@MainActor
final class PingSlot: Identifiable {
    let id = UUID()
    let host: String
    var customName: String

    private(set) var lastRtt: Double?
    private(set) var avgRtt: Double?
    private(set) var loss: Double = 0
    private(set) var sent: Int = 0
    private(set) var samples: [RTTSample] = []
    private(set) var isRunning = false

    private static let historyLimit = 120
    /// Minimum samples before threshold alerts can fire — avoids a single
    /// early timeout reading as "100% loss".
    private static let alertMinSamples = 10
    private static let alertCooldown: TimeInterval = 300

    @ObservationIgnored private let subprocess = StreamingSubprocess()
    @ObservationIgnored private var lastAlert: Date?

    init(host: String) {
        self.host = host
        self.customName = host
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        runPing()
    }

    func stop() {
        subprocess.stop()
        isRunning = false
    }

    private func runPing() {
        do {
            try subprocess.run(executable: "/sbin/ping",
                               arguments: ["-i", "1", host],
                               onChunk: { [weak self] text in
                let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
                let parsed = lines.compactMap { Self.parseLine($0) }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    for r in parsed { self.addResult(r) }
                }
            }, onTerminate: {})
        } catch {
            isRunning = false
        }
    }

    private func addResult(_ rtt: Double?) {
        let sample = RTTSample(timestamp: Date(), rtt: rtt)
        samples.append(sample)
        if samples.count > Self.historyLimit {
            samples.removeFirst(samples.count - Self.historyLimit)
        }
        sent += 1
        lastRtt = rtt
        let valid = samples.compactMap { $0.rtt }
        avgRtt = valid.isEmpty ? nil : valid.reduce(0, +) / Double(valid.count)
        let timeouts = samples.filter { $0.rtt == nil }.count
        loss = Double(timeouts) / Double(samples.count) * 100
        maybeAlert()
    }

    /// Fires a notification when loss or average RTT crosses the thresholds
    /// from Settings > Thresholds, at most once per cooldown per host.
    private func maybeAlert() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "multiPingAlerts"),
              samples.count >= Self.alertMinSamples else { return }
        if let lastAlert, Date().timeIntervalSince(lastAlert) < Self.alertCooldown { return }

        let lossLimit = defaults.object(forKey: "lossAlertThreshold") as? Double ?? 10
        let rttCrit   = defaults.object(forKey: "rttCritThreshold") as? Double ?? 100

        if loss >= lossLimit {
            lastAlert = Date()
            Notifier.post(title: "Packet loss: \(customName)",
                          body: String(format: "%.0f%% of the last %d pings to %@ were lost.",
                                       loss, samples.count, host))
        } else if let avgRtt, avgRtt >= rttCrit {
            lastAlert = Date()
            Notifier.post(title: "High latency: \(customName)",
                          body: String(format: "Average RTT to %@ is %.0f ms (critical threshold %.0f ms).",
                                       host, avgRtt, rttCrit))
        }
    }

    nonisolated static func parseLine(_ line: String) -> Double?? {
        // Case-insensitive: real ping emits "Request timeout..." and
        // "ping: sendto: No route to host" (capital N) — both are losses.
        let lower = line.lowercased()
        if lower.contains("request timeout") || lower.contains("no route") { return .some(nil) }
        guard let matchRange = line.range(of: #"time[=<]([\d.]+)"#, options: .regularExpression) else { return nil }
        let sub = String(line[matchRange])
        let value = sub.components(separatedBy: CharacterSet(charactersIn: "=<")).last ?? ""
        guard let ms = Double(value) else { return nil }
        return .some(ms)
    }
}

enum MultiPingSort: String, CaseIterable, Identifiable {
    case alias = "Alias Name"
    case host = "Hostname/IP"
    case latency = "Latency"
    case loss = "Packet Loss"
    var id: String { self.rawValue }
}

@Observable
@MainActor
final class MultiPingViewModel {
    var slots: [PingSlot] = []
    var sortMode: MultiPingSort = .alias {
        didSet { sortSlots() }
    }

    func add(host: String) {
        guard !host.trimmingCharacters(in: .whitespaces).isEmpty,
              !slots.contains(where: { $0.host == host }) else { return }
        let slot = PingSlot(host: host)
        slots.append(slot)
        slot.start()
        sortSlots()
    }

    func remove(_ slot: PingSlot) {
        slot.stop()
        slots.removeAll { $0.id == slot.id }
    }

    func stopAll() { slots.forEach { $0.stop() } }
    func startAll() { slots.forEach { $0.start() } }
    
    func sortSlots() {
        slots.sort { a, b in
            switch sortMode {
            case .alias:
                return a.customName.localizedCompare(b.customName) == .orderedAscending
            case .host:
                return a.host.localizedCompare(b.host) == .orderedAscending
            case .latency:
                return (a.avgRtt ?? 999999) < (b.avgRtt ?? 999999)
            case .loss:
                return a.loss > b.loss
            }
        }
    }
}
