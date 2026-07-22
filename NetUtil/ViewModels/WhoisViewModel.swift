import Foundation
import Observation

@Observable
@MainActor
final class WhoisViewModel {
    private(set) var lines: [WhoisLine] = []
    private(set) var isRunning = false
    private(set) var error: String?
    private(set) var lastQuery: String = ""
    var onSessionComplete: ((SessionRecord) -> Void)? = nil
    @ObservationIgnored private let subprocess = CancellableSubprocess()

    /// Generation token: bumped on stop/start so output of a terminated
    /// whois can't populate the result of a newer query.
    private var runID = 0

    func start(_ query: String) {
        stop()
        isRunning = true; error = nil; lines = []; lastQuery = query
        runID += 1
        let id = runID
        do {
            try subprocess.launch(executable: "/usr/bin/whois", arguments: [query])
        } catch {
            self.error = error.localizedDescription
            isRunning = false
            return
        }
        let start = Date()
        Task { [weak self] in
            guard let output = await self?.subprocess.collectOutput() else { return }
            let result = Self.parse(output)
            guard let self, self.runID == id else { return }
            self.lines = result
            self.isRunning = false
            let fields = result.filter { $0.label != nil }.count
            self.onSessionComplete?(SessionRecord(
                tool: "whois", target: query,
                summary: "\(fields) field\(fields == 1 ? "" : "s") parsed",
                status: fields > 0 ? .success : .partial,
                duration: Date().timeIntervalSince(start)))
        }
    }

    nonisolated static func parse(_ output: String) -> [WhoisLine] {
        var parsed: [WhoisLine] = []
        for l in output.components(separatedBy: "\n") {
            if l.contains(": "), let idx = l.firstIndex(of: ":") {
                let key = String(l[..<idx]).trimmingCharacters(in: .whitespaces)
                let val = String(l[l.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                if key.count < 30 { parsed.append(WhoisLine(raw: l, label: key, value: val)); continue }
            }
            parsed.append(WhoisLine(raw: l))
        }
        return parsed
    }

    func stop() {
        runID += 1
        subprocess.terminate()
        isRunning = false
    }
}
