import Foundation
import Observation

@Observable
@MainActor
final class NetQualityViewModel {
    private(set) var result: NetQualityResult?
    private(set) var isRunning = false
    private(set) var error: String?

    func clearError() { error = nil }
    var onSessionComplete: ((SessionRecord) -> Void)? = nil

    @ObservationIgnored private let subprocess = CancellableSubprocess()

    /// Generation token: bumped on stop/start so output of a terminated
    /// networkQuality run can't populate the result of a newer one.
    private var runID = 0

    func start(interface: String? = nil, privateRelay: Bool = false) {
        stop()
        error = nil
        result = nil
        isRunning = true
        runID += 1
        let id = runID

        let args = Self.netQualityArguments(interface: interface, privateRelay: privateRelay)

        do {
            try subprocess.launch(executable: "/usr/bin/networkQuality", arguments: args)
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
            guard var parsed = Self.parse(output) else {
                self.error = "networkQuality produced no parseable result"
                return
            }
            parsed.usedPrivateRelay = privateRelay
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

    /// Pure arg builder for `/usr/bin/networkQuality`. Unit-tested.
    nonisolated static func netQualityArguments(interface: String?, privateRelay: Bool) -> [String] {
        var args = ["-c"]
        if let interface, !interface.isEmpty { args += ["-I", interface] }
        if privateRelay { args += ["-p"] }
        return args
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
