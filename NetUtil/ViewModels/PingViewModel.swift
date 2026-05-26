import Foundation
import Combine

@MainActor
class PingViewModel: ObservableObject {
    @Published var results: [PingResult] = []
    @Published var stats = PingStats()
    @Published var isRunning = false
    @Published var rawLines: [String] = []
    @Published var error: String?

    private var process: Process?
    private var outputPipe: Pipe?

    private static let rawLinesLimit = 500

    // Pre-compiled — avoids re-compiling regex per packet
    private nonisolated static let pingPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(
            pattern: #"(\d+) bytes from (.*?): icmp_seq=(\d+) ttl=(\d+) time=(\d+\.?\d*) ms"#),
        try! NSRegularExpression(
            pattern: #"(\d+) bytes from (.*?): icmp6_seq=(\d+) hlim=(\d+) time=(\d+\.?\d*) ms"#)
    ]

    deinit {
        process?.terminate()
    }

    func start(host: String, count: Int?, interval: Double) {
        stop()
        results.removeAll()
        rawLines.removeAll()
        stats = PingStats()
        error = nil
        isRunning = true

        let p = Process()
        let pipe = Pipe()

        p.executableURL = URL(fileURLWithPath: "/sbin/ping")
        var args: [String] = []
        if let count { args += ["-c", "\(count)"] }
        args += ["-i", "\(max(0.2, interval))", host]
        p.arguments = args
        p.standardOutput = pipe
        p.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            guard let self else { return }
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

            // Parse on background thread (readabilityHandler is already background)
            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            let parsed = lines.compactMap { Self.parseLine($0) }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rawLines.append(contentsOf: lines)
                if self.rawLines.count > Self.rawLinesLimit {
                    self.rawLines.removeFirst(self.rawLines.count - Self.rawLinesLimit)
                }
                for result in parsed {
                    self.results.append(result)
                    self.stats.transmitted += 1
                    self.stats.record(rtt: result.rtt)
                }
            }
        }

        p.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
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
            isRunning = false
        }
    }

    func stop() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        outputPipe = nil
        isRunning = false
    }

    private nonisolated static func parseLine(_ line: String) -> PingResult? {
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
                ttl: ttl,
                rtt: rtt
            )
        }
        return nil
    }
}
