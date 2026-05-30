import Foundation
import Combine
import Observation

@Observable
@MainActor
final class PingSlot: Identifiable {
    let id = UUID()
    let host: String
    var customName: String

    var lastRtt: Double?
    var avgRtt: Double?
    var loss: Double = 0
    var sent: Int = 0
    var samples: [RTTSample] = []
    var isRunning = false

    private static let historyLimit = 120
    nonisolated(unsafe) private var process: Process?
    private var pipe: Pipe?

    init(host: String) { 
        self.host = host 
        self.customName = host
    }

    deinit { process?.terminate() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        runPing()
    }

    func stop() {
        pipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        pipe = nil
        isRunning = false
    }

    private func runPing() {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/sbin/ping")
        p.arguments = ["-i", "1", host]
        p.standardOutput = pipe
        p.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            let parsed = lines.compactMap { Self.parseLine($0) }
            Task { @MainActor [weak self] in
                guard let self else { return }
                for r in parsed { self.addResult(r) }
            }
        }

        self.process = p
        self.pipe = pipe

        do { try p.run() } catch { isRunning = false }
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
