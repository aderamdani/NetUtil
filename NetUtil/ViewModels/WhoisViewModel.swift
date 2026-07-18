import Foundation
import Observation

@Observable
@MainActor
final class WhoisViewModel {
    var lines: [WhoisLine] = []
    var isRunning = false
    var error: String?
    var lastQuery: String = ""
    var onSessionComplete: ((SessionRecord) -> Void)? = nil
    private var process: Process?

    /// Generation token: bumped on cancel/lookup so output of a terminated
    /// whois can't populate the result of a newer query.
    private var runID = 0

    func lookup(_ query: String) {
        cancel()
        isRunning = true; error = nil; lines = []; lastQuery = query
        runID += 1
        let id = runID
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/whois"); p.arguments = [query]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        process = p
        do { try p.run() } catch {
            self.error = error.localizedDescription
            process = nil
            isRunning = false
            return
        }
        // Drain to EOF while the process runs — reading only after exit can
        // deadlock once whois output fills the 64 KB pipe buffer.
        let start = Date()
        Task.detached { [weak self] in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            var parsed: [WhoisLine] = []
            for l in output.components(separatedBy: "\n") {
                if l.contains(": "), let idx = l.firstIndex(of: ":") {
                    let key = String(l[..<idx]).trimmingCharacters(in: .whitespaces)
                    let val = String(l[l.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                    if key.count < 30 { parsed.append(WhoisLine(raw: l, label: key, value: val)); continue }
                }
                parsed.append(WhoisLine(raw: l))
            }
            let result = parsed
            await MainActor.run { [weak self] in
                guard let self, self.runID == id else { return }
                self.lines = result
                self.process = nil
                self.isRunning = false
                let fields = result.filter { $0.label != nil }.count
                self.onSessionComplete?(SessionRecord(
                    tool: "whois", target: query,
                    summary: "\(fields) field\(fields == 1 ? "" : "s") parsed",
                    status: fields > 0 ? .success : .partial,
                    duration: Date().timeIntervalSince(start)))
            }
        }
    }

    func cancel() {
        runID += 1
        process?.terminate()
        process = nil
        isRunning = false
    }
}
