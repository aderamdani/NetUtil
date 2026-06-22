import Foundation
import Observation

@Observable
@MainActor
final class WhoisViewModel {
    var lines: [WhoisLine] = []
    var isRunning = false
    var error: String?
    var lastQuery: String = ""
    private var process: Process?

    func lookup(_ query: String) {
        isRunning = true; error = nil; lines = []; lastQuery = query
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/whois"); p.arguments = [query]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        p.terminationHandler = { _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                var parsed: [WhoisLine] = []
                for l in output.components(separatedBy: "\n") {
                    if l.contains(": "), let idx = l.firstIndex(of: ":") {
                        let key = String(l[..<idx]).trimmingCharacters(in: .whitespaces)
                        let val = String(l[l.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                        if key.count < 30 { parsed.append(WhoisLine(raw: l, label: key, value: val)); continue }
                    }
                    parsed.append(WhoisLine(raw: l))
                }
                self.lines = parsed; self.isRunning = false
            }
        }
        process = p
        do { try p.run() } catch { self.error = error.localizedDescription; isRunning = false }
    }
    
    func cancel() { process?.terminate(); process = nil; isRunning = false }
}
