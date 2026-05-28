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
    private var downloadTask: URLSessionDataTask?
    private var uploadTask: URLSessionUploadTask?
    private var startTime: Date?
    private var bytesReceived: Int64 = 0
    private var isRunning = false

    // Cloudflare speed test endpoints (open, no auth)
    private let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=104857600")! // 100 MB
    private let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
    private let latencyURL = URL(string: "https://speed.cloudflare.com/__down?bytes=0")!

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
        downloadTask?.cancel()
        uploadTask?.cancel()
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

    // MARK: - Download

    private func measureDownload() async throws -> Double {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let testDuration: TimeInterval = 10

        var totalBytes: Int64 = 0
        let t0 = Date()

        while Date().timeIntervalSince(t0) < testDuration {
            var req = URLRequest(url: downloadURL)
            req.timeoutInterval = 30
            let (bytes, _) = try await session.bytes(for: req)

            for try await _ in bytes {
                totalBytes &+= 1
                if totalBytes.isMultiple(of: 65536) {
                    let elapsed = Date().timeIntervalSince(t0)
                    progress = min(elapsed / testDuration / 2, 0.5)
                    let mbps = Double(totalBytes) * 8 / 1_000_000 / max(elapsed, 0.1)
                    downloadMbps = mbps
                    if elapsed >= testDuration { break }
                }
            }
            if Date().timeIntervalSince(t0) >= testDuration { break }
        }

        let elapsed = Date().timeIntervalSince(t0)
        return Double(totalBytes) * 8 / 1_000_000 / max(elapsed, 0.1)
    }

    // MARK: - Upload

    private func measureUpload() async throws -> Double {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let testDuration: TimeInterval = 10
        let chunkSize = 1_048_576 // 1 MB chunks
        let payload = Data(count: chunkSize)

        var totalBytes: Int64 = 0
        let t0 = Date()

        while Date().timeIntervalSince(t0) < testDuration {
            var req = URLRequest(url: uploadURL)
            req.httpMethod = "POST"
            req.timeoutInterval = 30
            req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            req.httpBody = payload

            _ = try await session.data(for: req)
            totalBytes &+= Int64(chunkSize)
            let elapsed = Date().timeIntervalSince(t0)
            progress = 0.5 + min(elapsed / testDuration / 2, 0.5)
            uploadMbps = Double(totalBytes) * 8 / 1_000_000 / max(elapsed, 0.1)
        }

        let elapsed = Date().timeIntervalSince(t0)
        return Double(totalBytes) * 8 / 1_000_000 / max(elapsed, 0.1)
    }
}
