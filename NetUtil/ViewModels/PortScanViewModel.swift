import Foundation
import Network
import Combine
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

    private(set) var startTime: Date?
    var elapsed: TimeInterval { startTime.map { Date().timeIntervalSince($0) } ?? 0 }
    var eta: TimeInterval? {
        guard scanned > 0, total > scanned else { return nil }
        let rate = Double(scanned) / elapsed
        return Double(total - scanned) / rate
    }

    private var scanTask: Task<Void, Never>?

    func scan(host: String, ports: [Int], concurrency: Int, timeout: Double) {
        stop()
        results = []
        scanned = 0
        openCount = 0
        total = ports.count
        error = nil
        startTime = Date()
        isRunning = true

        scanTask = Task.detached { [weak self] in
            await Self.runScan(host: host, ports: ports,
                               concurrency: concurrency, timeout: timeout) { result in
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.scanned += 1
                    self.results.append(result)
                    if result.status == .open { self.openCount += 1 }
                }
            }
            await MainActor.run { [weak self] in self?.isRunning = false }
        }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
        isRunning = false
    }

    // MARK: - Core scan (off main actor)

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
        let status: PortStatus = await withCheckedContinuation { continuation in
            let conn = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tcp
            )
            var done = false

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard !done else { return }
                    done = true
                    conn.cancel()
                    continuation.resume(returning: .open)
                case .failed:
                    guard !done else { return }
                    done = true
                    conn.cancel()
                    continuation.resume(returning: .closed)
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .utility))

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard !done else { return }
                done = true
                conn.cancel()
                continuation.resume(returning: .filtered)
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
