import Foundation
import Observation

@Observable
@MainActor
final class PathMTUViewModel {
    struct Probe: Identifiable {
        let id = UUID()
        let payload: Int
        let passed: Bool
        var packetSize: Int { payload + 28 }
    }

    private(set) var probes: [Probe] = []
    private(set) var mtu: Int?
    private(set) var isRunning = false
    private(set) var error: String?
    private(set) var currentHost = ""
    var onSessionComplete: ((SessionRecord) -> Void)? = nil

    /// IPv4 header (20) + ICMP header (8) — payload N means an N+28 byte packet.
    nonisolated static let headerOverhead = 28
    /// Smallest payload worth probing (IPv4 minimum MTU 68).
    nonisolated static let minPayload = 40
    /// Largest payload a standard 1500-byte Ethernet MTU can carry.
    nonisolated static let maxPayload = 1472

    /// Generation token: bumped on stop/start so a cancelled sweep can't
    /// keep appending probes to a newer one.
    private var runID = 0

    /// Injected for tests; the default shells out to `ping -D` (don't-fragment).
    private let probe: @Sendable (String, Int) async -> Bool

    init(probe: (@Sendable (String, Int) async -> Bool)? = nil) {
        self.probe = probe ?? Self.pingProbe
    }

    func start(host: String) {
        stop()
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        probes = []
        mtu = nil
        error = nil
        currentHost = target
        isRunning = true
        runID += 1
        let id = runID
        Task { [weak self] in
            await self?.discover(host: target, id: id)
        }
    }

    func stop() {
        runID += 1
        isRunning = false
    }

    /// Binary search for the largest payload that survives with the
    /// don't-fragment flag set. Internal (not private) so tests can await it.
    func discover(host: String, id: Int) async {
        let started = Date()

        // Fast path: a full Ethernet frame fits — path MTU is at least 1500.
        if await record(host: host, payload: Self.maxPayload, id: id) {
            finish(mtu: Self.maxPayload + Self.headerOverhead, host: host, started: started, id: id)
            return
        }
        guard runID == id else { return }

        // Sanity: if even the minimum survives nothing, the host isn't answering.
        guard await record(host: host, payload: Self.minPayload, id: id) else {
            guard runID == id else { return }
            error = "\(host) did not answer even minimum-size pings — the host may block ICMP or be unreachable."
            isRunning = false
            return
        }
        guard runID == id else { return }

        var passing = Self.minPayload
        var failing = Self.maxPayload
        while failing - passing > 1 {
            let mid = (passing + failing) / 2
            if await record(host: host, payload: mid, id: id) {
                passing = mid
            } else {
                failing = mid
            }
            guard runID == id else { return }
        }
        finish(mtu: passing + Self.headerOverhead, host: host, started: started, id: id)
    }

    private func record(host: String, payload: Int, id: Int) async -> Bool {
        let ok = await probe(host, payload)
        guard runID == id else { return ok }
        probes.append(Probe(payload: payload, passed: ok))
        return ok
    }

    private func finish(mtu value: Int, host: String, started: Date, id: Int) {
        guard runID == id else { return }
        mtu = value
        isRunning = false
        onSessionComplete?(SessionRecord(
            tool: "pathMTU", target: host,
            summary: "Path MTU \(value) — \(Self.interpretation(mtu: value))",
            status: value >= 1500 ? .success : .partial,
            duration: Date().timeIntervalSince(started)))
    }

    // MARK: - Interpretation

    nonisolated static func interpretation(mtu: Int) -> String {
        switch mtu {
        case 1500...: "standard Ethernet, no tunnel overhead"
        case 1492:    "PPPoE (typical DSL)"
        case 1420...1460: "tunnel overhead — common for WireGuard/IPsec VPNs"
        case 1280...1419: "heavy tunnel overhead or IPv6-minimum path"
        default:      "unusually small — expect fragmentation issues"
        }
    }

    private static let pingProbe: @Sendable (String, Int) async -> Bool = { host, payload in
        let output = SubprocessRunner.run(
            executable: "/sbin/ping",
            arguments: ["-c", "1", "-t", "2", "-D", "-s", "\(payload)", host],
            mergeStderr: true)
        return output.contains("bytes from")
    }
}
