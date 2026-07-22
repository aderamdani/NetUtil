import Foundation
import Observation

enum DoctorStepID: String, CaseIterable, Identifiable {
    case gateway = "Router"
    case dns     = "DNS"
    case http    = "Internet"
    case tls     = "Secure Web"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gateway: "wifi.router"
        case .dns:     "globe"
        case .http:    "network"
        case .tls:     "lock.shield"
        }
    }

    /// One-line plain-language description of what the step checks.
    var explanation: String {
        switch self {
        case .gateway: "Can this Mac reach your router?"
        case .dns:     "Can names like apple.com be turned into addresses?"
        case .http:    "Does web traffic actually get out to the internet?"
        case .tls:     "Do encrypted (https) connections work?"
        }
    }
}

enum DoctorStepState: Equatable {
    case pending
    case running
    case passed(String)
    case failed(String)
}

struct DoctorCheck: Identifiable {
    let id: DoctorStepID
    var state: DoctorStepState = .pending
}

@Observable
@MainActor
final class NetworkDoctorViewModel {
    private(set) var checks: [DoctorCheck] = DoctorStepID.allCases.map { DoctorCheck(id: $0) }
    private(set) var isRunning = false
    private(set) var captivePortal = false
    private(set) var lastRun: Date?
    var onSessionComplete: ((SessionRecord) -> Void)? = nil

    /// Generation token: bumped on stop/start so a cancelled diagnosis
    /// can't keep mutating the checks of a newer one.
    private var runID = 0

    func start() {
        stop()
        checks = DoctorStepID.allCases.map { DoctorCheck(id: $0) }
        captivePortal = false
        isRunning = true
        runID += 1
        let id = runID
        let started = Date()

        Task { [weak self] in
            for step in DoctorStepID.allCases {
                guard let self, self.runID == id else { return }
                self.setState(.running, for: step)
                let result = await Self.run(step: step)
                guard self.runID == id else { return }
                if case .failed(let why) = result, why.contains("Captive portal") {
                    self.captivePortal = true
                }
                self.setState(result, for: step)
            }
            guard let self, self.runID == id else { return }
            self.isRunning = false
            self.lastRun = Date()
            let verdict = Self.verdict(for: self.checks, captivePortal: self.captivePortal)
            self.onSessionComplete?(SessionRecord(
                tool: "doctor", target: "connectivity",
                summary: verdict.message,
                status: verdict.color == "green" ? .success : verdict.color == "orange" ? .partial : .failed,
                duration: Date().timeIntervalSince(started)))
        }
    }

    func stop() {
        runID += 1
        isRunning = false
    }

    private func setState(_ state: DoctorStepState, for step: DoctorStepID) {
        guard let idx = checks.firstIndex(where: { $0.id == step }) else { return }
        checks[idx].state = state
    }

    // MARK: - Steps

    private nonisolated static func run(step: DoctorStepID) async -> DoctorStepState {
        switch step {
        case .gateway: await checkGateway()
        case .dns:     await checkDNS()
        case .http:    await checkHTTP()
        case .tls:     await checkTLS()
        }
    }

    private nonisolated static func checkGateway() async -> DoctorStepState {
        guard let (gateway, iface) = GatewayParser.anyDefaultGateway() else {
            return .failed("No default route — this Mac is not connected to any network. Check Wi-Fi or the Ethernet cable.")
        }
        let output = SubprocessRunner.run(executable: "/sbin/ping",
                                          arguments: ["-c", "1", "-t", "2", gateway])
        if output.contains("bytes from") {
            return .passed("Router \(gateway) answered on \(iface)")
        }
        return .failed("Router \(gateway) did not answer. The link is up but the router is unreachable — try restarting it.")
    }

    private nonisolated static func checkDNS() async -> DoctorStepState {
        let output = SubprocessRunner.run(executable: "/usr/bin/dig",
                                          arguments: ["+time=2", "+tries=1", "+short", "apple.com"])
        let answer = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !answer.isEmpty, answer.contains(".") {
            return .passed("apple.com resolved to \(answer.components(separatedBy: "\n").first ?? answer)")
        }
        return .failed("Name lookup failed. The network is up but DNS is not answering — try a public resolver like 1.1.1.1 or 8.8.8.8 in System Settings > Network > DNS.")
    }

    private nonisolated static func checkHTTP() async -> DoctorStepState {
        guard let url = URL(string: "http://captive.apple.com/hotspot-detect.html") else {
            return .failed("Internal error building probe URL")
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let body = String(decoding: data, as: UTF8.self)
            if body.contains("Success") {
                return .passed("Web traffic reaches the internet")
            }
            return .failed("Captive portal detected — this network wants you to log in first. Open a browser and complete the sign-in page.")
        } catch {
            return .failed("Web request failed: \(error.localizedDescription)")
        }
    }

    private nonisolated static func checkTLS() async -> DoctorStepState {
        guard let url = URL(string: "https://www.apple.com") else {
            return .failed("Internal error building probe URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 5
        do {
            _ = try await URLSession.shared.data(for: req)
            return .passed("Encrypted connections work")
        } catch {
            return .failed("Secure connection failed: \(error.localizedDescription). A firewall or proxy may be intercepting https traffic.")
        }
    }

    // MARK: - Verdict

    /// Maps the completed checks to one plain-language conclusion.
    nonisolated static func verdict(for checks: [DoctorCheck], captivePortal: Bool)
        -> (icon: String, color: String, message: String) {
        func failed(_ id: DoctorStepID) -> Bool {
            if case .failed = checks.first(where: { $0.id == id })?.state { return true }
            return false
        }
        if captivePortal {
            return ("person.crop.circle.badge.questionmark", "orange",
                    "Captive portal — sign in to this network in your browser first")
        }
        if failed(.gateway) {
            return ("wifi.exclamationmark", "red", "Not connected — this Mac can't reach a router")
        }
        if failed(.dns) {
            return ("exclamationmark.triangle.fill", "red", "DNS is broken — connected to the router, but names don't resolve")
        }
        if failed(.http) {
            return ("exclamationmark.triangle.fill", "red", "No internet — router and DNS work, but traffic doesn't get out")
        }
        if failed(.tls) {
            return ("lock.trianglebadge.exclamationmark", "orange", "Encrypted traffic is failing — something may be intercepting https")
        }
        return ("checkmark.circle.fill", "green", "All layers healthy — connectivity looks good")
    }
}
