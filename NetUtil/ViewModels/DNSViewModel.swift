import Foundation
import Observation

@Observable
@MainActor
final class DNSViewModel {
    private(set) var result: DNSResult?
    private(set) var isRunning = false
    private(set) var rawOutput = ""
    private(set) var error: String?
    private(set) var lastQuery: String = ""
    var onSessionComplete: ((SessionRecord) -> Void)? = nil

    @ObservationIgnored private let subprocess = CancellableSubprocess()

    /// Generation token: bumped on cancel/lookup so output of a terminated
    /// dig can't populate the result of a newer query.
    private var runID = 0

    func start(host: String, type: DNSRecordType, server: DNSServer) {
        stop()
        result = nil
        rawOutput = ""
        error = nil
        isRunning = true
        lastQuery = host
        runID += 1
        let id = runID

        var args: [String] = ["+noall", "+answer", "+stats", "+comments"]
        if let addr = server.address { args.append("@\(addr)") }
        args += [host, type.rawValue]

        do {
            try subprocess.launch(executable: "/usr/bin/dig", arguments: args)
        } catch {
            self.error = error.localizedDescription
            isRunning = false
            return
        }

        let start = Date()
        Task { [weak self] in
            guard let output = await self?.subprocess.collectOutput() else { return }
            guard let self, self.runID == id else { return }
            self.rawOutput = output
            let parsed = Self.parse(output: output, serverAddress: server.address)
            self.result = parsed
            self.isRunning = false
            self.logSession(parsed, host: host, type: type, started: start)
        }
    }

    private func logSession(_ result: DNSResult, host: String, type: DNSRecordType, started: Date) {
        let n = result.records.count
        let ms = result.queryTimeMs.map { "\($0) ms" } ?? "—"
        let record = SessionRecord(
            tool: "dns", target: host,
            summary: "\(type.rawValue): \(n) record\(n == 1 ? "" : "s")  —  \(ms) via \(result.server)",
            status: n > 0 ? .success : .partial,
            duration: Date().timeIntervalSince(started))
        onSessionComplete?(record)
    }

    func stop() {
        runID += 1
        subprocess.terminate()
        isRunning = false
    }

    nonisolated static func parse(output: String, serverAddress: String?) -> DNSResult {
        var records: [DNSRecord] = []
        var queryTimeMs: Int?
        var resolvedServer = serverAddress ?? "system"
        var inAnswer = false

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix(";; ANSWER SECTION") {
                inAnswer = true; continue
            }
            if trimmed.hasPrefix(";;") {
                if inAnswer { inAnswer = false }

                // ;; Query time: 23 msec
                if trimmed.contains("Query time:"),
                   let ms = trimmed.components(separatedBy: ":").last?
                       .trimmingCharacters(in: .whitespaces)
                       .components(separatedBy: " ").first
                       .flatMap(Int.init) {
                    queryTimeMs = ms
                }
                // ;; SERVER: 8.8.8.8#53(8.8.8.8)
                if trimmed.contains("SERVER:"),
                   let srv = trimmed.components(separatedBy: "SERVER:").last?
                       .trimmingCharacters(in: .whitespaces)
                       .components(separatedBy: "#").first {
                    resolvedServer = srv
                }
                continue
            }

            guard inAnswer, !trimmed.isEmpty else { continue }

            let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            // name ttl IN type value...
            guard tokens.count >= 5 else { continue }
            let name = tokens[0]
            let ttl  = Int(tokens[1]) ?? 0
            // tokens[2] = "IN"
            let rtype = tokens[3]
            let value = tokens[4...].joined(separator: " ")

            records.append(DNSRecord(name: name, ttl: ttl, type: rtype, value: value))
        }

        return DNSResult(
            server: resolvedServer,
            queryTimeMs: queryTimeMs,
            records: records,
            timestamp: Date()
        )
    }
}
