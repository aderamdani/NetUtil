import Foundation
import Combine

struct AppTrafficItem: Identifiable, Equatable {
    let id: String
    let name: String
    let rxBps: Double
    let txBps: Double
}

@MainActor
class TopProcessesViewModel: ObservableObject {
    @Published var apps: [AppTrafficItem] = []
    @Published var isRunning = false
    @Published var error: String?

    private var process: Process?
    private var pipe: Pipe?
    private var buffer = Data()
    private var pendingRows: [String] = []
    private var sampleCount = 0
    private var lastSampleTime: Date?

    func start() {
        stop()
        isRunning = true
        error = nil
        lastSampleTime = nil
        sampleCount = 0

        let p = Process()
        let pipe = Pipe()
        // nettop requires a tty — wrap in /usr/bin/script to fake one
        p.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        p.arguments = ["-q", "/dev/null",
                       "/usr/bin/nettop",
                       "-P",   // process-level (not thread)
                       "-d",   // delta mode
                       "-x",   // machine-readable CSV
                       "-L", "0", // continuous
                       "-s", "2", // 2-second interval
                       "-J", "bytes_in,bytes_out"]
        p.standardOutput = pipe
        p.standardError = Pipe()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor [weak self] in self?.consume(data) }
        }
        p.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in self?.isRunning = false }
        }

        self.process = p
        self.pipe = pipe
        do {
            try p.run()
        } catch {
            self.error = error.localizedDescription
            self.isRunning = false
        }
    }

    func stop() {
        pipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        pipe = nil
        isRunning = false
        buffer = Data()
        pendingRows = []
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let idx = buffer.firstRange(of: Data([0x0A])) {
            let lineData = buffer[..<idx.lowerBound]
            buffer.removeSubrange(..<idx.upperBound)
            var line = String(data: lineData, encoding: .utf8) ?? ""
            if line.hasSuffix("\r") { line.removeLast() }
            processLine(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func processLine(_ line: String) {
        guard !line.isEmpty else { return }
        if line == ",bytes_in,bytes_out," {
            flushSample()
        } else {
            pendingRows.append(line)
        }
    }

    private func flushSample() {
        defer {
            pendingRows.removeAll(keepingCapacity: true)
            sampleCount += 1
            lastSampleTime = Date()
        }
        guard sampleCount > 0, !pendingRows.isEmpty else { return }
        let now = Date()
        let elapsed = max(now.timeIntervalSince(lastSampleTime ?? now.addingTimeInterval(-2)), 0.5)

        var totals: [String: (rx: UInt64, tx: UInt64)] = [:]
        for row in pendingRows {
            let parts = row.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }
            let rawID = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let name = processName(from: rawID)
            let rx = UInt64(String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let tx = UInt64(String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            guard rx > 0 || tx > 0 else { continue }
            let prev = totals[name] ?? (0, 0)
            totals[name] = (prev.rx + rx, prev.tx + tx)
        }

        apps = totals.map { name, bytes in
            AppTrafficItem(id: name, name: name,
                           rxBps: Double(bytes.rx) / elapsed,
                           txBps: Double(bytes.tx) / elapsed)
        }
        .filter { $0.rxBps > 500 || $0.txBps > 500 }
        .sorted { max($0.rxBps, $0.txBps) > max($1.rxBps, $1.txBps) }
        .prefix(10)
        .map { $0 }
    }

    private func processName(from rawID: String) -> String {
        guard let dot = rawID.lastIndex(of: ".") else { return rawID }
        return String(rawID[..<dot])
    }
}
