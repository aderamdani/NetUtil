import Foundation
import Combine

enum SpeedTestKind: String, CaseIterable, Identifiable {
    case speed     = "Speed"
    case browsing  = "Browsing"
    case gaming    = "Gaming"
    case streaming = "Streaming"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .speed:     return "speedometer"
        case .browsing:  return "safari"
        case .gaming:    return "gamecontroller.fill"
        case .streaming: return "play.tv.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .speed:     return "Download, upload, ping, jitter"
        case .browsing:  return "TTFB and full-page load timing"
        case .gaming:    return "Latency, jitter, packet loss"
        case .streaming: return "Sustained throughput tier rating"
        }
    }
}

enum SpeedTestPhase: String {
    case idle      = "Idle"
    case latency   = "Measuring latency..."
    case download  = "Testing download..."
    case upload    = "Testing upload..."
    case browsing  = "Loading sites..."
    case gaming    = "Probing gaming server..."
    case streaming = "Measuring stream stability..."
    case done      = "Complete"
    case failed    = "Failed"
}

// MARK: - Results

struct SpeedTestResult: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let kindRaw: String   // SpeedTestKind.rawValue (Codable-friendly)
    let provider: String
    var name: String?     // user-editable label
    // Speed
    var downloadMbps: Double = 0
    var uploadMbps: Double = 0
    var pingMs: Double = 0
    var jitterMs: Double = 0
    // Browsing
    var browsingAvgMs: Double = 0
    var browsingMedianTtfb: Double = 0
    var browsingSites: Int = 0
    // Gaming
    var gameMedianMs: Double = 0
    var gameP99Ms: Double = 0
    var gameJitterMs: Double = 0
    var gameLossPct: Double = 0
    // Streaming
    var streamAvgMbps: Double = 0
    var streamMinMbps: Double = 0
    var streamTier: String = "—"

    var kind: SpeedTestKind { SpeedTestKind(rawValue: kindRaw) ?? .speed }
}

// MARK: - ViewModel

@MainActor
class SpeedTestViewModel: NSObject, ObservableObject {
    @Published var kind: SpeedTestKind = .speed
    @Published var phase: SpeedTestPhase = .idle
    @Published var progress: Double = 0
    @Published var lastResult: SpeedTestResult?
    @Published var history: [SpeedTestResult] = []
    @Published var error: String?

    // Speed live values
    @Published var downloadMbps: Double = 0
    @Published var uploadMbps: Double = 0
    @Published var pingMs: Double = 0
    @Published var jitterMs: Double = 0

    // Browsing live values
    @Published var browsingAvgMs: Double = 0
    @Published var browsingMedianTtfb: Double = 0
    @Published var browsingProcessed: Int = 0

    // Gaming live values
    @Published var gameMedianMs: Double = 0
    @Published var gameP99Ms: Double = 0
    @Published var gameJitterMs: Double = 0
    @Published var gameLossPct: Double = 0

    // Streaming live values
    @Published var streamAvgMbps: Double = 0
    @Published var streamMinMbps: Double = 0
    @Published var streamTier: String = "—"

    private var isRunning = false
    private var cancelTransfer = false

    // Cloudflare speed test endpoints (open, no auth)
    private let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
    private let latencyURL = URL(string: "https://speed.cloudflare.com/__down?bytes=0")!
    private let downloadChunkURL = URL(string: "https://speed.cloudflare.com/__down?bytes=26214400")! // 25 MB

    private static let historyDefaultsKey = "speedTestHistory"
    private static let historyLimit = 50

    var isTesting: Bool { isRunning }

    override init() {
        super.init()
        loadHistory()
    }

    // MARK: - History persistence + rename

    func renameResult(_ id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let idx = history.firstIndex(where: { $0.id == id }) else { return }
        history[idx].name = trimmed.isEmpty ? nil : trimmed
        saveHistory()
    }

    func deleteResult(_ id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.historyDefaultsKey),
              let decoded = try? JSONDecoder().decode([SpeedTestResult].self, from: data) else { return }
        history = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyDefaultsKey)
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        error = nil
        progress = 0
        resetLive()
        Task { await runTest() }
    }

    func cancel() {
        cancelTransfer = true
        isRunning = false
        phase = .idle
    }

    private func resetLive() {
        downloadMbps = 0; uploadMbps = 0; pingMs = 0; jitterMs = 0
        browsingAvgMs = 0; browsingMedianTtfb = 0; browsingProcessed = 0
        gameMedianMs = 0; gameP99Ms = 0; gameJitterMs = 0; gameLossPct = 0
        streamAvgMbps = 0; streamMinMbps = 0; streamTier = "—"
    }

    private func runTest() async {
        cancelTransfer = false
        do {
            switch kind {
            case .speed:     try await runSpeed()
            case .browsing:  try await runBrowsing()
            case .gaming:    try await runGaming()
            case .streaming: try await runStreaming()
            }
            phase = .done
            progress = 1.0
        } catch {
            self.error = (error as NSError).localizedDescription
            phase = .failed
        }
        isRunning = false
    }

    // MARK: - Speed (download + upload + ping + jitter)

    private func runSpeed() async throws {
        // Phase 1: latency
        phase = .latency
        let (ping, jitter) = try await measurePing(samples: 8)
        pingMs = ping
        jitterMs = jitter
        progress = 0.1

        // Phase 2: download (10s sustained, parallel)
        phase = .download
        let dl = try await measureDownload(parallel: 4, duration: 10, progressStart: 0.1, progressEnd: 0.55)
        downloadMbps = dl

        // Phase 3: upload (10s sustained)
        phase = .upload
        let ul = try await measureUpload(duration: 10, progressStart: 0.55, progressEnd: 1.0)
        uploadMbps = ul

        var result = SpeedTestResult(timestamp: Date(), kindRaw: SpeedTestKind.speed.rawValue, provider: "Cloudflare")
        result.downloadMbps = dl
        result.uploadMbps = ul
        result.pingMs = ping
        result.jitterMs = jitter
        recordResult(result)
    }

    // MARK: - Browsing (sequential HTTP load timing)

    private func runBrowsing() async throws {
        phase = .browsing
        let urls = [
            "https://www.google.com",
            "https://www.cloudflare.com",
            "https://www.wikipedia.org",
            "https://www.github.com",
            "https://www.apple.com",
            "https://duckduckgo.com",
            "https://www.bing.com",
            "https://www.reddit.com",
        ]
        var ttfbs: [Double] = []
        var totals: [Double] = []
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)

        for (i, urlStr) in urls.enumerated() {
            if cancelTransfer { break }
            guard let url = URL(string: urlStr) else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Mozilla/5.0 NetUtil-BrowsingTest", forHTTPHeaderField: "User-Agent")
            let t0 = Date()
            do {
                let (data, response) = try await session.data(for: req)
                let total = Date().timeIntervalSince(t0) * 1000
                // Approximate TTFB by re-running a HEAD request quickly
                var headReq = req
                headReq.httpMethod = "HEAD"
                let t1 = Date()
                _ = try? await session.data(for: headReq)
                let ttfb = Date().timeIntervalSince(t1) * 1000
                totals.append(total)
                ttfbs.append(ttfb)
                _ = data; _ = response
            } catch { continue }
            browsingProcessed = i + 1
            browsingAvgMs = totals.reduce(0, +) / Double(totals.count)
            browsingMedianTtfb = median(ttfbs)
            progress = Double(i + 1) / Double(urls.count)
        }
        session.invalidateAndCancel()

        var result = SpeedTestResult(timestamp: Date(), kindRaw: SpeedTestKind.browsing.rawValue, provider: "Mixed sites")
        result.browsingAvgMs = browsingAvgMs
        result.browsingMedianTtfb = browsingMedianTtfb
        result.browsingSites = browsingProcessed
        recordResult(result)
    }

    // MARK: - Gaming (sustained latency + jitter + loss)

    private func runGaming() async throws {
        phase = .gaming
        let target = URL(string: "https://1.1.1.1/cdn-cgi/trace")!
        let probeCount = 50
        var samples: [Double] = []
        var failures = 0
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 3
        let session = URLSession(configuration: config)

        for i in 0..<probeCount {
            if cancelTransfer { break }
            var req = URLRequest(url: target)
            req.httpMethod = "HEAD"
            let t0 = Date()
            do {
                _ = try await session.data(for: req)
                samples.append(Date().timeIntervalSince(t0) * 1000)
            } catch {
                failures += 1
            }
            // 50 ms between probes — burst pattern that mimics real game traffic
            try? await Task.sleep(nanoseconds: 50_000_000)

            if !samples.isEmpty {
                let sorted = samples.sorted()
                gameMedianMs = sorted[sorted.count / 2]
                let p99idx = min(sorted.count - 1, Int(Double(sorted.count) * 0.99))
                gameP99Ms = sorted[p99idx]
                let mean = samples.reduce(0, +) / Double(samples.count)
                let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count)
                gameJitterMs = sqrt(variance)
            }
            gameLossPct = Double(failures) / Double(i + 1) * 100
            progress = Double(i + 1) / Double(probeCount)
        }
        session.invalidateAndCancel()

        var result = SpeedTestResult(timestamp: Date(), kindRaw: SpeedTestKind.gaming.rawValue, provider: "1.1.1.1 HTTP probe")
        result.gameMedianMs = gameMedianMs
        result.gameP99Ms = gameP99Ms
        result.gameJitterMs = gameJitterMs
        result.gameLossPct = gameLossPct
        recordResult(result)
    }

    // MARK: - Streaming (sustained throughput stability tier)

    private func runStreaming() async throws {
        phase = .streaming
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)
        let testDuration: TimeInterval = 15
        let t0 = Date()
        let deadline = t0.addingTimeInterval(testDuration)

        var windowSamples: [Double] = []
        var lastWindowStart = t0
        var windowBytes: Int64 = 0
        var totalBytes: Int64 = 0

        while Date() < deadline && !cancelTransfer {
            var req = URLRequest(url: downloadChunkURL)
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            req.timeoutInterval = 30
            do {
                let (data, _) = try await session.data(for: req)
                totalBytes &+= Int64(data.count)
                windowBytes &+= Int64(data.count)
            } catch { break }

            let now = Date()
            let windowElapsed = now.timeIntervalSince(lastWindowStart)
            if windowElapsed >= 1.0 {
                let mbps = Double(windowBytes) * 8 / 1_000_000 / windowElapsed
                windowSamples.append(mbps)
                streamAvgMbps = windowSamples.reduce(0, +) / Double(windowSamples.count)
                streamMinMbps = windowSamples.min() ?? 0
                lastWindowStart = now
                windowBytes = 0
            }
            let elapsed = now.timeIntervalSince(t0)
            progress = min(elapsed / testDuration, 1.0)

            // Update streaming tier verdict
            streamTier = tierLabel(forMin: streamMinMbps)
        }
        session.invalidateAndCancel()

        var result = SpeedTestResult(timestamp: Date(), kindRaw: SpeedTestKind.streaming.rawValue, provider: "Cloudflare")
        result.streamAvgMbps = streamAvgMbps
        result.streamMinMbps = streamMinMbps
        result.streamTier = streamTier
        recordResult(result)
    }

    private func tierLabel(forMin minMbps: Double) -> String {
        if minMbps >= 50 { return "8K UHD" }
        if minMbps >= 25 { return "4K UHD" }
        if minMbps >= 8  { return "1080p HD" }
        if minMbps >= 5  { return "720p HD" }
        if minMbps >= 2.5 { return "480p SD" }
        if minMbps > 0   { return "240p" }
        return "—"
    }

    // MARK: - Building Blocks

    private func measurePing(samples count: Int) async throws -> (Double, Double) {
        var samples: [Double] = []
        for _ in 0..<count {
            if cancelTransfer { break }
            let t0 = Date()
            var req = URLRequest(url: latencyURL)
            req.timeoutInterval = 5
            _ = try? await URLSession.shared.data(for: req)
            samples.append(Date().timeIntervalSince(t0) * 1000)
        }
        guard !samples.isEmpty else { return (0, 0) }
        let sorted = samples.sorted()
        let med = sorted[sorted.count / 2]
        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count)
        return (med, sqrt(variance))
    }

    private func measureDownload(parallel: Int, duration: TimeInterval, progressStart: Double, progressEnd: Double) async throws -> Double {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpMaximumConnectionsPerHost = parallel
        let session = URLSession(configuration: config)

        let t0 = Date()
        let deadline = t0.addingTimeInterval(duration)

        // Use TaskGroup for parallel chunk downloads
        let actor = ByteCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<parallel {
                group.addTask { [weak self] in
                    guard let self else { return }
                    while await !self.cancelTransferOrPastDeadline(deadline) {
                        var req = URLRequest(url: self.downloadChunkURL)
                        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                        req.timeoutInterval = 30
                        do {
                            let (data, _) = try await session.data(for: req)
                            await actor.add(Int64(data.count))
                        } catch { return }
                    }
                }
                group.addTask { [weak self] in
                    guard let self else { return }
                    while await !self.cancelTransferOrPastDeadline(deadline) {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        let total = await actor.value
                        let elapsed = Date().timeIntervalSince(t0)
                        await MainActor.run {
                            self.downloadMbps = Double(total) * 8 / 1_000_000 / max(elapsed, 0.1)
                            self.progress = progressStart + (progressEnd - progressStart) * min(elapsed / duration, 1.0)
                        }
                    }
                }
            }
            await group.waitForAll()
        }

        session.invalidateAndCancel()
        let elapsed = Date().timeIntervalSince(t0)
        let total = await actor.value
        guard elapsed > 0, total > 0 else { return 0 }
        return Double(total) * 8 / 1_000_000 / elapsed
    }

    nonisolated private func cancelTransferOrPastDeadline(_ deadline: Date) async -> Bool {
        let cancelled = await MainActor.run { self.cancelTransfer }
        return cancelled || Date() >= deadline
    }

    private func measureUpload(duration: TimeInterval, progressStart: Double, progressEnd: Double) async throws -> Double {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)
        let chunkSize = 4_194_304 // 4 MB
        let payload = Data(count: chunkSize)
        var totalBytes: Int64 = 0
        let t0 = Date()
        let deadline = t0.addingTimeInterval(duration)

        while Date() < deadline && !cancelTransfer {
            var req = URLRequest(url: uploadURL)
            req.httpMethod = "POST"
            req.timeoutInterval = 30
            req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            req.setValue("\(chunkSize)", forHTTPHeaderField: "Content-Length")
            do {
                _ = try await session.upload(for: req, from: payload)
                totalBytes &+= Int64(chunkSize)
            } catch { break }

            let elapsed = Date().timeIntervalSince(t0)
            progress = progressStart + (progressEnd - progressStart) * min(elapsed / duration, 1.0)
            uploadMbps = Double(totalBytes) * 8 / 1_000_000 / max(elapsed, 0.1)
        }

        session.invalidateAndCancel()
        let elapsed = Date().timeIntervalSince(t0)
        return Double(totalBytes) * 8 / 1_000_000 / max(elapsed, 0.1)
    }

    // MARK: - Helpers

    private func recordResult(_ result: SpeedTestResult) {
        lastResult = result
        history.insert(result, at: 0)
        if history.count > Self.historyLimit { history.removeLast() }
        saveHistory()
    }

    private func median(_ samples: [Double]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.sorted()
        return sorted[sorted.count / 2]
    }
}

// MARK: - Byte Counter Actor (thread-safe atomic counter)

private actor ByteCounter {
    private(set) var value: Int64 = 0
    func add(_ n: Int64) { value &+= n }
}
