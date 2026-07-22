import Foundation
import Combine
import AppKit
import Observation

@MainActor
@Observable
final class PingViewModel {
    private(set) var results: [PingResult] = []
    /// Throttled snapshot for chart rendering — updates at ~5fps max
    private(set) var chartResults: [PingResult] = []
    private(set) var stats = PingStats()
    private(set) var isRunning = false
    private(set) var rawLines: [PingLogLine] = []
    private(set) var error: String?
    private(set) var resolvedIP: String?
    private(set) var beepOnLoss: Bool = false
    private(set) var currentHost: String = ""
    var quickLaunchHost: String? = nil
    var onSessionComplete: ((SessionRecord) -> Void)? = nil

    @ObservationIgnored private var subprocess = StreamingSubprocess()
    @ObservationIgnored private var sessionStartTime: Date = Date()

    private static let rawLinesLimit = 500
    private static let resultsLimit  = 1000

    @ObservationIgnored private var resultsBuffer: [PingResult] = []
    @ObservationIgnored private var batchTimer: AnyCancellable?
    @ObservationIgnored private var lastChartFlush: Date = .distantPast

    /// Generation token: bumped on every stop/start so a terminated process's
    /// pending handlers can't tear down or pollute a newer run.
    @ObservationIgnored private var runID = 0
    @ObservationIgnored private var sessionLogged = true

    // Pre-compiled — avoids re-compiling regex per packet
    private nonisolated static let pingPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(\d+) bytes from (.*?): icmp_seq=(\d+) ttl=(\d+) time=(\d+\.?\d*) ms"#,
            #"(\d+) bytes from (.*?): icmp6_seq=(\d+) hlim=(\d+) time=(\d+\.?\d*) ms"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()
    
    private nonisolated static let headerPattern = try? NSRegularExpression(
        pattern: #"PING .*? \((.*?)\):"#
    )

    private nonisolated static let timeoutPattern = try? NSRegularExpression(
        pattern: #"Request timeout for icmp(?:6)?_seq (\d+)"#
    )

    func start(host: String, count: Int?, interval: Double, packetSize: Int? = nil) {
        stop()
        results.removeAll()
        rawLines.removeAll()
        resultsBuffer.removeAll()
        stats = PingStats()
        error = nil
        resolvedIP = nil
        currentHost = host
        isRunning = true
        sessionStartTime = Date()
        sessionLogged = false
        runID += 1
        let id = runID

        // Batch timer: update UI every 100ms instead of per packet
        batchTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.flushBuffer()
            }

        var args: [String] = []
        if let count { args += ["-c", "\(count)"] }
        if let packetSize { args += ["-s", "\(packetSize)"] }
        args += ["-i", "\(max(0.2, interval))", host]

        do {
            try subprocess.run(executable: "/sbin/ping", arguments: args, onChunk: { [weak self] text in
                guard let self else { return }

                // Parse on background thread
                let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }

                // Check for IP in header
                var foundIP: String?
                for line in lines {
                    if let ip = Self.parseHeader(line) {
                        foundIP = ip
                        break
                    }
                }

                let parsed = lines.compactMap { Self.parseLine($0, ip: foundIP) }
                let timeouts = lines.compactMap { Self.parseTimeout($0) }
                let resolved = foundIP

                Task { @MainActor [weak self] in
                    guard let self, self.runID == id else { return }
                    if let resolved { self.resolvedIP = resolved }

                    let newLogLines = lines.map { PingLogLine(text: $0) }
                    self.rawLines.append(contentsOf: newLogLines)
                    if self.rawLines.count > Self.rawLinesLimit {
                        self.rawLines.removeFirst(self.rawLines.count - Self.rawLinesLimit)
                    }

                    // Buffer the results instead of direct append
                    for result in parsed {
                        self.resultsBuffer.append(result)
                    }
                    for timeoutSeq in timeouts {
                        if self.beepOnLoss {
                            NSSound(named: "Tink")?.play()
                        }

                        self.resultsBuffer.append(PingResult(
                            sequence: timeoutSeq,
                            bytes: 0,
                            host: host,
                            ipAddress: self.resolvedIP,
                            ttl: 0,
                            rtt: 0,
                            status: .timeout
                        ))
                    }
                }
            }, onTerminate: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.runID == id else { return }
                    self.flushBuffer() // Final flush
                    self.chartResults = self.results // Ensure chart gets last snapshot
                    self.batchTimer = nil
                    self.subprocess.stop()
                    self.isRunning = false
                    self.logSession() // Finite (-c) runs end here, not via stop()
                }
            })
        } catch {
            self.error = error.localizedDescription
            self.batchTimer = nil
            isRunning = false
        }
    }

    private func flushBuffer() {
        guard !resultsBuffer.isEmpty else { return }
        
        // Record stats for all buffered items
        for r in resultsBuffer {
            if r.status == .success {
                stats.record(rtt: r.rtt)
            } else {
                stats.recordTimeout()
            }
        }
        
        results.append(contentsOf: resultsBuffer)
        resultsBuffer.removeAll()
        
        if results.count > Self.resultsLimit {
            results.removeFirst(results.count - Self.resultsLimit)
        }
        
        // Throttle chart data to ~5fps (200ms) — avoids 10fps full chart redraw
        let now = Date()
        if now.timeIntervalSince(lastChartFlush) >= 0.2 {
            chartResults = results
            lastChartFlush = now
        }
    }

    func stop() {
        runID += 1
        batchTimer = nil
        subprocess.stop()
        isRunning = false
        logSession()
    }

    private func logSession() {
        guard !sessionLogged else { return }
        sessionLogged = true
        guard stats.transmitted > 0, !currentHost.isEmpty else { return }
        let duration = Date().timeIntervalSince(sessionStartTime)
        let summary = String(format: "%d pkts, %.1f%% loss, avg %.1f ms",
                             stats.transmitted, stats.loss, stats.avgRtt)
        let status: SessionStatus = stats.loss > 50 ? .failed : stats.loss > 0 ? .partial : .success
        var record = SessionRecord(tool: "ping", target: currentHost,
                                   summary: summary, status: status, duration: duration)
        record.pingStats = PingStatsSnapshot(
            transmitted: stats.transmitted, received: stats.received,
            avgRtt: stats.avgRtt,
            minRtt: stats.minRtt == .infinity ? 0 : stats.minRtt,
            maxRtt: stats.maxRtt, jitter: stats.jitter)
        onSessionComplete?(record)
    }

    nonisolated static func parseHeader(_ line: String) -> String? {
        guard let pattern = headerPattern,
              let m = pattern.firstMatch(
            in: line, range: NSRange(line.startIndex..., in: line)
        ) else { return nil }

        let r = m.range(at: 1)
        guard r.location != NSNotFound, let range = Range(r, in: line) else { return nil }
        return String(line[range])
    }

    nonisolated static func parseTimeout(_ line: String) -> Int? {
        guard let pattern = timeoutPattern,
              let m = pattern.firstMatch(
            in: line, range: NSRange(line.startIndex..., in: line)
        ) else { return nil }

        let r = m.range(at: 1)
        guard r.location != NSNotFound, let range = Range(r, in: line) else { return nil }
        return Int(line[range])
    }

    nonisolated static func parseLine(_ line: String, ip: String?) -> PingResult? {
        for regex in pingPatterns {
            guard let m = regex.firstMatch(
                in: line, range: NSRange(line.startIndex..., in: line)
            ) else { continue }

            func cap(_ i: Int) -> String? {
                let r = m.range(at: i)
                guard r.location != NSNotFound, let range = Range(r, in: line) else { return nil }
                return String(line[range])
            }

            guard let bytes = cap(1).flatMap(Int.init),
                  let host  = cap(2),
                  let seq   = cap(3).flatMap(Int.init),
                  let ttl   = cap(4).flatMap(Int.init),
                  let rtt   = cap(5).flatMap(Double.init) else { continue }

            return PingResult(
                sequence: seq,
                bytes: bytes,
                host: host.trimmingCharacters(in: .whitespaces),
                ipAddress: ip,
                ttl: ttl,
                rtt: rtt,
                status: .success
            )
        }
        return nil
    }
}
