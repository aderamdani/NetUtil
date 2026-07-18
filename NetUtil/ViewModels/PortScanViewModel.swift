import Foundation
import Network
import Observation

@Observable
@MainActor
final class PortScanViewModel {
    private(set) var results: [PortResult] = []
    private(set) var isRunning = false
    private(set) var scanned = 0
    private(set) var total = 0
    private(set) var openCount = 0
    private(set) var error: String?
    private(set) var currentHost: String = ""

    private(set) var startTime: Date?
    var quickLaunchHost: String? = nil
    var onSessionComplete: ((SessionRecord) -> Void)? = nil
    var elapsed: TimeInterval { startTime.map { Date().timeIntervalSince($0) } ?? 0 }
    var eta: TimeInterval? {
        guard scanned > 0, total > scanned else { return nil }
        let rate = Double(scanned) / elapsed
        return Double(total - scanned) / rate
    }

    private var scanTask: Task<Void, Never>?

    /// Generation token: bumped on stop/scan so results of a cancelled scan
    /// can't leak into a newer one.
    private var runID = 0
    private var sessionLogged = true

    func scan(host: String, ports: [Int], concurrency: Int, timeout: Double) {
        stop()
        results = []
        scanned = 0
        openCount = 0
        total = ports.count
        error = nil
        startTime = Date()
        currentHost = host
        isRunning = true
        sessionLogged = false
        runID += 1
        let id = runID

        scanTask = Task.detached { [weak self] in
            await Self.runScan(host: host, ports: ports,
                               concurrency: concurrency, timeout: timeout) { result in
                await MainActor.run { [weak self] in
                    guard let self, self.runID == id else { return }
                    self.scanned += 1
                    self.results.append(result)
                    if result.status == .open { self.openCount += 1 }
                }
            }
            await MainActor.run { [weak self] in
                guard let self, self.runID == id else { return }
                self.isRunning = false
                self.logSession() // Completed scans end here, not via stop()
            }
        }
    }

    func stop() {
        runID += 1
        scanTask?.cancel()
        scanTask = nil
        isRunning = false
        logSession()
    }

    private func logSession() {
        guard !sessionLogged else { return }
        sessionLogged = true
        guard !results.isEmpty, !currentHost.isEmpty else { return }
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let summary = "\(scanned) ports scanned, \(openCount) open"
        let status: SessionStatus = openCount > 0 ? .success : .partial
        var record = SessionRecord(tool: "portScan", target: currentHost,
                                   summary: summary, status: status, duration: duration)
        record.portResults = results.map { PortResultSnapshot(port: $0.port, service: $0.service, isOpen: $0.status == .open) }
        onSessionComplete?(record)
    }

    // MARK: - Core scan (off main actor)

    private nonisolated final class ScanState: @unchecked Sendable {
        private let lock = NSLock()
        private var _isDone = false
        var isDone: Bool {
            lock.lock()
            defer { lock.unlock() }
            return _isDone
        }
        func setDone() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if _isDone { return false }
            _isDone = true
            return true
        }
    }

    private static func runScan(
        host: String,
        ports: [Int],
        concurrency: Int,
        timeout: Double,
        onResult: @escaping (PortResult) async -> Void
    ) async {
        await withTaskGroup(of: PortResult.self) { group in
            var index = 0

            // Seed initial batch
            let seedCount = min(concurrency, ports.count)
            for i in 0..<seedCount {
                let port = ports[i]
                group.addTask { await checkPort(port: port, host: host, timeout: timeout) }
                index = i + 1
            }

            // Sliding window
            for await result in group {
                if Task.isCancelled { group.cancelAll(); break }
                await onResult(result)
                if index < ports.count {
                    let port = ports[index]
                    group.addTask { await checkPort(port: port, host: host, timeout: timeout) }
                    index += 1
                }
            }
        }
    }

    private static func checkPort(port: Int, host: String, timeout: Double) async -> PortResult {
        let start = Date()
        let scanState = ScanState()
        
        let status: PortStatus = await withCheckedContinuation { continuation in
            let conn = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tcp
            )

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if scanState.setDone() {
                        conn.cancel()
                        continuation.resume(returning: .open)
                    }
                case .failed:
                    if scanState.setDone() {
                        conn.cancel()
                        continuation.resume(returning: .closed)
                    }
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .utility))

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if scanState.setDone() {
                    conn.cancel()
                    continuation.resume(returning: .filtered)
                }
            }
        }

        let ms = Date().timeIntervalSince(start) * 1000
        return PortResult(
            port: port,
            status: status,
            service: wellKnownPorts[port],
            responseMs: status == .open ? ms : nil
        )
    }
}
