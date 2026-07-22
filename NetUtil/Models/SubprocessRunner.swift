import Foundation

/// Runs a CLI tool to completion, draining its output pipe fully before
/// waiting for exit (waiting first can deadlock once output fills the pipe
/// buffer). For one-shot commands (`dig`, `whois`, `arp -an`, `host`, `ifconfig`, …).
enum SubprocessRunner {
    /// `mergeStderr: true` folds stderr into the same captured output as
    /// stdout; otherwise stderr is left to inherit the parent process's
    /// (i.e. not captured, not discarded).
    nonisolated static func run(executable: String, arguments: [String], mergeStderr: Bool = false) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        if mergeStderr { process.standardError = pipe }

        do {
            try process.run()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// Runs a CLI tool that streams output continuously (`ping`, `traceroute`, …),
/// delivering chunks as they arrive and a callback on exit. Both callbacks
/// fire on the pipe's background readability queue, not MainActor — hop
/// back yourself (e.g. `Task { @MainActor in ... } `) to apply results.
final class StreamingSubprocess {
    nonisolated(unsafe) private var process: Process?
    private var pipe: Pipe?

    func run(executable: String, arguments: [String],
             onChunk: @escaping (String) -> Void,
             onTerminate: @escaping () -> Void) throws {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        p.standardOutput = pipe
        p.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            onChunk(text)
        }
        p.terminationHandler = { _ in onTerminate() }

        process = p
        self.pipe = pipe
        try p.run()
    }

    func stop() {
        pipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        pipe = nil
    }

    deinit { process?.terminate() }
}
