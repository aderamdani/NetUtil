import Foundation
import Combine
import AppKit

@MainActor
class PingViewModel: ObservableObject {
    @Published var results: [PingResult] = []
    @Published var stats = PingStats()
    @Published var isRunning = false
    @Published var rawLines: [String] = []
    @Published var error: String?
    @Published var resolvedIP: String?
    @Published var beepOnLoss: Bool = false
    @Published var currentHost: String = ""

    private var process: Process?
    private var outputPipe: Pipe?

    private static let rawLinesLimit = 500
    private static let resultsLimit  = 1000

    private var resultsBuffer: [PingResult] = []
    private var batchTimer: AnyCancellable?

    // Pre-compiled — avoids re-compiling regex per packet
    private nonisolated static let pingPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(
            pattern: #"(\d+) bytes from (.*?): icmp_seq=(\d+) ttl=(\d+) time=(\d+\.?\d*) ms"#),
        try! NSRegularExpression(
            pattern: #"(\d+) bytes from (.*?): icmp6_seq=(\d+) hlim=(\d+) time=(\d+\.?\d*) ms"#)
    ]
    
    private nonisolated static let headerPattern = try! NSRegularExpression(
        pattern: #"PING .*? \((.*?)\):"#
    )

    private nonisolated static let timeoutPattern = try! NSRegularExpression(
        pattern: #"Request timeout for icmp(?:6)?_seq (\d+)"#
    )

    deinit {
        process?.terminate()
    }

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
        
        // Batch timer: update UI every 100ms instead of per packet
        batchTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.flushBuffer()
            }

        let p = Process()
        let pipe = Pipe()

        p.executableURL = URL(fileURLWithPath: "/sbin/ping")
        var args: [String] = []
        if let count { args += ["-c", "\(count)"] }
        if let packetSize { args += ["-s", "\(packetSize)"] }
        args += ["-i", "\(max(0.2, interval))", host]
        p.arguments = args
        p.standardOutput = pipe
        p.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            guard let self else { return }
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

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
                guard let self else { return }
                if let resolved { self.resolvedIP = resolved }
                
                self.rawLines.append(contentsOf: lines)
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
        }

        p.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.flushBuffer() // Final flush
                self?.batchTimer = nil
                self?.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self?.isRunning = false
            }
        }

        process = p
        outputPipe = pipe

        do {
            try p.run()
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
    }

    func stop() {
        batchTimer = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        outputPipe = nil
        isRunning = false
    }

    private nonisolated static func parseHeader(_ line: String) -> String? {
        guard let m = headerPattern.firstMatch(
            in: line, range: NSRange(line.startIndex..., in: line)
        ) else { return nil }

        let r = m.range(at: 1)
        guard r.location != NSNotFound, let range = Range(r, in: line) else { return nil }
        return String(line[range])
    }

    private nonisolated static func parseTimeout(_ line: String) -> Int? {
        guard let m = timeoutPattern.firstMatch(
            in: line, range: NSRange(line.startIndex..., in: line)
        ) else { return nil }

        let r = m.range(at: 1)
        guard r.location != NSNotFound, let range = Range(r, in: line) else { return nil }
        return Int(line[range])
    }

    private nonisolated static func parseLine(_ line: String, ip: String?) -> PingResult? {
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
