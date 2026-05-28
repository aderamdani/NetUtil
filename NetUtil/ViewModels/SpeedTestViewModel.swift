import Foundation
import Combine

enum SpeedTestPhase: String {
    case idle = "Idle"
    case latency = "Measuring latency..."
    case download = "Testing download..."
    case upload = "Testing upload..."
    case done = "Complete"
    case failed = "Failed"
}

struct SpeedTestResult: Identifiable {
    let id = UUID()
    let timestamp: Date
    let downloadMbps: Double
    let uploadMbps: Double
    let pingMs: Double
    let jitterMs: Double
    let provider: String
}

@MainActor
class SpeedTestViewModel: NSObject, ObservableObject {
    @Published var phase: SpeedTestPhase = .idle
    @Published var downloadMbps: Double = 0
    @Published var uploadMbps: Double = 0
    @Published var pingMs: Double = 0
    @Published var jitterMs: Double = 0
    @Published var progress: Double = 0
    @Published var lastResult: SpeedTestResult?
    @Published var history: [SpeedTestResult] = []
    @Published var error: String?

    private var session: URLSession?
    private var activeTasks: [URLSessionTask] = []
    private var isRunning = false

    // Cloudflare speed test endpoints (open, no auth)
    private let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=104857600")! // 100 MB
    private let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
    private let latencyURL = URL(string: "https://speed.cloudflare.com/__down?bytes=0")!

    // Live-updated counters during transfer phases.
    private var transferBytes: Int64 = 0
    private var transferStart: Date?
    private var transferDuration: TimeInterval = 10
    private var cancelTransfer = false

    var isTesting: Bool { isRunning }

    override init() {
        super.init()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        phase = .latency
        error = nil
        downloadMbps = 0
        uploadMbps = 0
        pingMs = 0
        jitterMs = 0
        progress = 0

        Task { await runFullTest() }
    }

    func cancel() {
        cancelTransfer = true
        for t in activeTasks { t.cancel() }
        activeTasks.removeAll()
        session?.invalidateAndCancel()
        session = nil
        isRunning = false
        phase = .idle
    }

    private func runFullTest() async {
        do {
            // ── Phase 1: Latency (5 pings) ──
            phase = .latency
            var samples: [Double] = []
            for _ in 0..<5 {
                let t0 = Date()
                var req = URLRequest(url: latencyURL)
                req.timeoutInterval = 5
                _ = try? await URLSession.shared.data(for: req)
                let rtt = Date().timeIntervalSince(t0) * 1000
                samples.append(rtt)
            }
            let sorted = samples.sorted()
            pingMs = sorted[sorted.count / 2]
            let mean = samples.reduce(0, +) / Double(samples.count)
            let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count)
            jitterMs = sqrt(variance)

            // ── Phase 2: Download (~10 s) ──
            phase = .download
            let dl = try await measureDownload()
            downloadMbps = dl

            // ── Phase 3: Upload (~10 s) ──
            phase = .upload
            let ul = try await measureUpload()
            uploadMbps = ul

            // ── Done ──
            let result = SpeedTestResult(timestamp: Date(),
                                         downloadMbps: dl, uploadMbps: ul,
                                         pingMs: pingMs, jitterMs: jitterMs,
                                         provider: "Cloudflare")
            lastResult = result
            history.insert(result, at: 0)
            if history.count > 20 { history.removeLast() }
            phase = .done
            progress = 1.0
        } catch {
            self.error = (error as NSError).localizedDescription
            phase = .failed
        }
        isRunning = false
    }

    // MARK: - Download (delegate-based, chunk-counted)

    private func measureDownload() async throws -> Double {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpMaximumConnectionsPerHost = 4

        transferBytes = 0
        transferStart = Date()
        transferDuration = 10
        cancelTransfer = false

        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.session = session

        // Launch 4 parallel downloads to saturate the link.
        var tasks: [URLSessionDataTask] = []
        for _ in 0..<4 {
            let task = session.dataTask(with: downloadURL)
            tasks.append(task)
            activeTasks.append(task)
            task.resume()
        }

        // Sleep in small increments so cancel() can interrupt fast.
        let deadline = Date().addingTimeInterval(transferDuration)
        while Date() < deadline && !cancelTransfer {
            try await Task.sleep(nanoseconds: 100_000_000) // 100 ms
        }

        // Stop the downloads
        let taskIDs = Set(tasks.map(\.taskIdentifier))
        for t in tasks { t.cancel() }
        activeTasks.removeAll { taskIDs.contains($0.taskIdentifier) }
        session.invalidateAndCancel()
        self.session = nil

        let elapsed = Date().timeIntervalSince(transferStart ?? Date())
        let total = transferBytes
        guard elapsed > 0, total > 0 else { return 0 }
        return Double(total) * 8 / 1_000_000 / elapsed
    }

    // MARK: - Upload

    private func measureUpload() async throws -> Double {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)
        let testDuration: TimeInterval = 10
        let chunkSize = 4_194_304 // 4 MB chunks
        let payload = Data(count: chunkSize)

        var totalBytes: Int64 = 0
        let t0 = Date()

        while Date().timeIntervalSince(t0) < testDuration && !cancelTransfer {
            var req = URLRequest(url: uploadURL)
            req.httpMethod = "POST"
            req.timeoutInterval = 30
            req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            req.setValue("\(chunkSize)", forHTTPHeaderField: "Content-Length")

            do {
                _ = try await session.upload(for: req, from: payload)
                totalBytes &+= Int64(chunkSize)
            } catch {
                break
            }

            let elapsed = Date().timeIntervalSince(t0)
            progress = 0.5 + min(elapsed / testDuration / 2, 0.5)
            uploadMbps = Double(totalBytes) * 8 / 1_000_000 / max(elapsed, 0.1)
        }

        let elapsed = Date().timeIntervalSince(t0)
        return Double(totalBytes) * 8 / 1_000_000 / max(elapsed, 0.1)
    }
}

// MARK: - URLSessionDataDelegate (download chunk counting)

extension SpeedTestViewModel: URLSessionDataDelegate {
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let n = Int64(data.count)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.transferBytes &+= n
            if let start = self.transferStart {
                let elapsed = Date().timeIntervalSince(start)
                self.progress = min(elapsed / self.transferDuration / 2, 0.5)
                self.downloadMbps = Double(self.transferBytes) * 8 / 1_000_000 / max(elapsed, 0.1)
            }
        }
    }
}
