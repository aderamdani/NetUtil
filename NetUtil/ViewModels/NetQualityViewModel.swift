import Foundation
import Observation

@Observable
@MainActor
final class NetQualityViewModel {
    private(set) var result: NetQualityResult?
    private(set) var isRunning = false
    private(set) var error: String?
    var onSessionComplete: ((SessionRecord) -> Void)? = nil

    @ObservationIgnored private let subprocess = CancellableSubprocess()

    /// Generation token: bumped on stop/start so output of a terminated
    /// networkQuality run can't populate the result of a newer one.
    private var runID = 0

    func start() {
        stop()
        error = nil
        result = nil
        isRunning = true
        runID += 1
        let id = runID

        do {
            try subprocess.launch(executable: "/usr/bin/networkQuality", arguments: ["-c"])
        } catch {
            self.error = error.localizedDescription
            isRunning = false
            return
        }

        let started = Date()
        Task { [weak self] in
            guard let output = await self?.subprocess.collectOutput() else { return }
            guard let self, self.runID == id else { return }
            self.isRunning = false
            guard let parsed = Self.parse(output) else {
                self.error = "networkQuality produced no parseable result"
                return
            }
            self.result = parsed
            let grade = parsed.rpmGrade
            self.onSessionComplete?(SessionRecord(
                tool: "netQuality",
                target: parsed.endpoint ?? "apple.com",
                summary: "↓ \(String(format: "%.0f", parsed.downloadMbps)) / ↑ \(String(format: "%.0f", parsed.uploadMbps)) Mbps  —  \(parsed.responsivenessRPM) RPM (\(grade.label))",
                status: grade.label == "Low" ? .partial : .success,
                duration: Date().timeIntervalSince(started)))
        }
    }

    func stop() {
        runID += 1
        subprocess.terminate()
        isRunning = false
    }

    nonisolated static func parse(_ output: String) -> NetQualityResult? {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dl = json["dl_throughput"] as? Double,
              let ul = json["ul_throughput"] as? Double,
              let rpm = json["responsiveness"] as? Double else { return nil }
        return NetQualityResult(
            downloadMbps: dl / 1_000_000,
            uploadMbps: ul / 1_000_000,
            responsivenessRPM: Int(rpm.rounded()),
            baseRttMs: json["base_rtt"] as? Double,
            interfaceName: json["interface_name"] as? String,
            endpoint: json["test_endpoint"] as? String,
            timestamp: Date())
    }
}
