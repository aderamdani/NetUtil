import Foundation

@MainActor
protocol SpeedTestDelegate: AnyObject {
    var phase: SpeedTestPhase { get set }
    var progress: Double { get set }

    var downloadMbps: Double { get set }
    var uploadMbps: Double { get set }
    var pingMs: Double { get set }
    var jitterMs: Double { get set }

    var browsingAvgMs: Double { get set }
    var browsingMedianTtfb: Double { get set }
    var browsingProcessed: Int { get set }

    var gameMedianMs: Double { get set }
    var gameP99Ms: Double { get set }
    var gameJitterMs: Double { get set }
    var gameLossPct: Double { get set }

    var streamAvgMbps: Double { get set }
    var streamMinMbps: Double { get set }
    var streamTier: String { get set }
}

private class MetricsDelegate: NSObject, URLSessionTaskDelegate {
    var ttfb: TimeInterval = 0
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        if let transaction = metrics.transactionMetrics.last {
            if let fetchStart = transaction.fetchStartDate, let responseStart = transaction.responseStartDate {
                ttfb = responseStart.timeIntervalSince(fetchStart) * 1000
            }
        }
    }
}

@MainActor
final class SpeedTestEngine {
    weak var delegate: SpeedTestDelegate?
    private(set) var cancelTransfer = false

    // Cloudflare speed test endpoints (open, no auth)
    private static let uploadURL = URL(string: "https://speed.cloudflare.com/__up")
    private static let latencyURL = URL(string: "https://speed.cloudflare.com/__down?bytes=0")
    private static let downloadChunkURL = URL(string: "https://speed.cloudflare.com/__down?bytes=26214400") // 25 MB

    func cancel() {
        cancelTransfer = true
    }

    func runTest(kind: SpeedTestKind) async throws -> SpeedTestResult {
        cancelTransfer = false
        switch kind {
        case .speed:     return try await runSpeed()
        case .browsing:  return try await runBrowsing()
        case .gaming:    return try await runGaming()
        case .streaming: return try await runStreaming()
        }
    }

    // MARK: - Speed (download + upload + ping + jitter)

    private func runSpeed() async throws -> SpeedTestResult {
        // Phase 1: latency
        delegate?.phase = .latency
        let (ping, jitter) = try await measurePing(samples: 8)
        delegate?.pingMs = ping
        delegate?.jitterMs = jitter
        delegate?.progress = 0.1

        // Phase 2: download (10s sustained, parallel)
        delegate?.phase = .download
        let dl = try await measureDownload(parallel: 4, duration: 10, progressStart: 0.1, progressEnd: 0.55)
        delegate?.downloadMbps = dl

        // Phase 3: upload (10s sustained)
        delegate?.phase = .upload
        let ul = try await measureUpload(duration: 10, progressStart: 0.55, progressEnd: 1.0)
        delegate?.uploadMbps = ul

        var result = SpeedTestResult(timestamp: Date(), kind: .speed, provider: "Cloudflare")
        result.downloadMbps = dl
        result.uploadMbps = ul
        result.pingMs = ping
        result.jitterMs = jitter
        return result
    }

    // MARK: - Browsing (sequential HTTP load timing)

    private func runBrowsing() async throws -> SpeedTestResult {
        delegate?.phase = .browsing
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
            
            let metricsDelegate = MetricsDelegate()
            
            do {
                let (_, _) = try await session.data(for: req, delegate: metricsDelegate)
                let total = Date().timeIntervalSince(t0) * 1000
                let ttfb = metricsDelegate.ttfb > 0 ? metricsDelegate.ttfb : total
                totals.append(total)
                ttfbs.append(ttfb)
            } catch { continue }
            
            let currentProcessed = i + 1
            let currentAvg = totals.reduce(0, +) / Double(totals.count)
            let currentMedian = median(ttfbs)
            
            delegate?.browsingProcessed = currentProcessed
            delegate?.browsingAvgMs = currentAvg
            delegate?.browsingMedianTtfb = currentMedian
            delegate?.progress = Double(i + 1) / Double(urls.count)
        }
        session.invalidateAndCancel()

        var result = SpeedTestResult(timestamp: Date(), kind: .browsing, provider: "Mixed sites")
        result.browsingAvgMs = delegate?.browsingAvgMs ?? 0
        result.browsingMedianTtfb = delegate?.browsingMedianTtfb ?? 0
        result.browsingSites = delegate?.browsingProcessed ?? 0
        return result
    }

    // MARK: - Gaming (sustained latency + jitter + loss)

    private func runGaming() async throws -> SpeedTestResult {
        delegate?.phase = .gaming
        guard let target = URL(string: "https://1.1.1.1/cdn-cgi/trace") else {
            throw NSError(domain: "SpeedTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid gaming probe URL"])
        }
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
                let gameMedianMs = sorted[sorted.count / 2]
                let p99idx = min(sorted.count - 1, Int(Double(sorted.count) * 0.99))
                let gameP99Ms = sorted[p99idx]
                let mean = samples.reduce(0, +) / Double(samples.count)
                let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count)
                let gameJitterMs = sqrt(variance)
                
                delegate?.gameMedianMs = gameMedianMs
                delegate?.gameP99Ms = gameP99Ms
                delegate?.gameJitterMs = gameJitterMs
            }
            let gameLossPct = Double(failures) / Double(i + 1) * 100
            delegate?.gameLossPct = gameLossPct
            delegate?.progress = Double(i + 1) / Double(probeCount)
        }
        session.invalidateAndCancel()

        var result = SpeedTestResult(timestamp: Date(), kind: .gaming, provider: "1.1.1.1 HTTP probe")
        result.gameMedianMs = delegate?.gameMedianMs ?? 0
        result.gameP99Ms = delegate?.gameP99Ms ?? 0
        result.gameJitterMs = delegate?.gameJitterMs ?? 0
        result.gameLossPct = delegate?.gameLossPct ?? 0
        return result
    }

    // MARK: - Streaming (sustained throughput stability tier)

    private func runStreaming() async throws -> SpeedTestResult {
        delegate?.phase = .streaming
        guard let chunkURL = Self.downloadChunkURL else {
            throw NSError(domain: "SpeedTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid streaming download URL"])
        }
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
            var req = URLRequest(url: chunkURL)
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
                let streamAvgMbps = windowSamples.reduce(0, +) / Double(windowSamples.count)
                let streamMinMbps = windowSamples.min() ?? 0
                
                delegate?.streamAvgMbps = streamAvgMbps
                delegate?.streamMinMbps = streamMinMbps
                
                lastWindowStart = now
                windowBytes = 0
            }
            let elapsed = now.timeIntervalSince(t0)
            delegate?.progress = min(elapsed / testDuration, 1.0)

            // Update streaming tier verdict
            if let minMbps = delegate?.streamMinMbps {
                delegate?.streamTier = tierLabel(forMin: minMbps)
            }
        }
        session.invalidateAndCancel()

        var result = SpeedTestResult(timestamp: Date(), kind: .streaming, provider: "Cloudflare")
        result.streamAvgMbps = delegate?.streamAvgMbps ?? 0
        result.streamMinMbps = delegate?.streamMinMbps ?? 0
        result.streamTier = delegate?.streamTier ?? "—"
        return result
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
        guard let url = Self.latencyURL else { return (0, 0) }
        var samples: [Double] = []
        
        await withTaskGroup(of: Double?.self) { group in
            for i in 0..<count {
                group.addTask {
                    // Small stagger to prevent all requests from hitting at the exact same millisecond
                    try? await Task.sleep(nanoseconds: UInt64(i * 10_000_000))
                    let t0 = Date()
                    var req = URLRequest(url: url)
                    req.timeoutInterval = 5
                    req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                    do {
                        _ = try await URLSession.shared.data(for: req)
                        return Date().timeIntervalSince(t0) * 1000
                    } catch {
                        return nil
                    }
                }
            }
            for await result in group {
                if let r = result { samples.append(r) }
            }
        }
        
        guard !samples.isEmpty else { return (0, 0) }
        let sorted = samples.sorted()
        let med = sorted[sorted.count / 2]
        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count)
        return (med, sqrt(variance))
    }

    private func measureDownload(parallel: Int, duration: TimeInterval, progressStart: Double, progressEnd: Double) async throws -> Double {
        guard let chunkURL = Self.downloadChunkURL else { return 0 }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpMaximumConnectionsPerHost = parallel
        let session = URLSession(configuration: config)

        let t0 = Date()
        let deadline = t0.addingTimeInterval(duration)
        let actor = ByteCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<parallel {
                group.addTask { [weak self] in
                    guard let self else { return }
                    while await !self.cancelTransferOrPastDeadline(deadline) {
                        var req = URLRequest(url: chunkURL)
                        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                        req.timeoutInterval = 30
                        do {
                            let (data, _) = try await session.data(for: req)
                            await actor.add(Int64(data.count))
                        } catch { return }
                    }
                }
            }
            
            // Single progress updater task
            group.addTask { [weak self] in
                guard let self else { return }
                while await !self.cancelTransferOrPastDeadline(deadline) {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    let total = await actor.value
                    let elapsed = Date().timeIntervalSince(t0)
                    await MainActor.run {
                        self.delegate?.downloadMbps = Double(total) * 8 / 1_000_000 / max(elapsed, 0.1)
                        self.delegate?.progress = progressStart + (progressEnd - progressStart) * min(elapsed / duration, 1.0)
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
        guard let url = Self.uploadURL else { return 0 }
        let parallel = 4
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpMaximumConnectionsPerHost = parallel
        let session = URLSession(configuration: config)
        let chunkSize = 4_194_304 // 4 MB
        let t0 = Date()
        let deadline = t0.addingTimeInterval(duration)
        
        let actor = ByteCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<parallel {
                group.addTask { [weak self] in
                    guard let self else { return }
                    let payload = Data(count: chunkSize)
                    while await !self.cancelTransferOrPastDeadline(deadline) {
                        var req = URLRequest(url: url)
                        req.httpMethod = "POST"
                        req.timeoutInterval = 30
                        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                        req.setValue("\(chunkSize)", forHTTPHeaderField: "Content-Length")
                        do {
                            _ = try await session.upload(for: req, from: payload)
                            await actor.add(Int64(chunkSize))
                        } catch { return }
                    }
                }
            }
            
            // Single progress updater task
            group.addTask { [weak self] in
                guard let self else { return }
                while await !self.cancelTransferOrPastDeadline(deadline) {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    let total = await actor.value
                    let elapsed = Date().timeIntervalSince(t0)
                    await MainActor.run {
                        self.delegate?.uploadMbps = Double(total) * 8 / 1_000_000 / max(elapsed, 0.1)
                        self.delegate?.progress = progressStart + (progressEnd - progressStart) * min(elapsed / duration, 1.0)
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
