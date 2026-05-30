import Foundation
import Combine
import Observation

@Observable
@MainActor
final class DNSViewModel {
    var result: DNSResult?
    var isRunning = false
    var rawOutput = ""
    var error: String?

    nonisolated(unsafe) private var process: Process?
    private var outputPipe: Pipe?

    deinit { process?.terminate() }

    func lookup(host: String, type: DNSRecordType, server: DNSServer) {
        cancel()
        result = nil
        rawOutput = ""
        error = nil
        isRunning = true

        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/dig")

        var args: [String] = ["+noall", "+answer", "+stats", "+comments"]
        if let addr = server.address { args.append("@\(addr)") }
        args += [host, type.rawValue]
        p.arguments = args
        p.standardOutput = pipe
        p.standardError = pipe

        var buffer = ""

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            guard let self else { return }
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                buffer += text
                self.rawOutput += text
            }
        }

        p.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self.result = Self.parse(output: buffer, server: server)
                self.isRunning = false
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

    func cancel() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        outputPipe = nil
        isRunning = false
    }

    nonisolated static func parse(output: String, server: DNSServer) -> DNSResult {
        var records: [DNSRecord] = []
        var queryTimeMs: Int?
        var resolvedServer = server.address ?? "system"
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
