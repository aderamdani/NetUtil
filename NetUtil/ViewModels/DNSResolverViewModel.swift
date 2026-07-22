import Foundation
import Observation

@Observable
@MainActor
final class DNSResolverViewModel {
    private(set) var isRunning = false
    private(set) var error: String?
    private(set) var resolvers: [DNSResolverEntry] = []
    private(set) var lastUpdated: Date?

    @ObservationIgnored private var runID = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    /// The resolver macOS actually uses for ordinary (non-scoped) lookups.
    var primaryResolver: DNSResolverEntry? {
        resolvers.first { !$0.isScoped && !$0.nameservers.isEmpty }
    }

    /// General-purpose resolvers with at least one nameserver — skips the
    /// mDNS/link-local pseudo-entries that only exist to claim a domain.
    var effectiveResolvers: [DNSResolverEntry] {
        resolvers.filter { !$0.nameservers.isEmpty }
    }

    func start() {
        stop()
        runID += 1
        let myRun = runID
        isRunning = true
        error = nil

        task = Task.detached { [weak self] in
            let output = SubprocessRunner.run(executable: "/usr/sbin/scutil", arguments: ["--dns"])
            var parsed = DNSResolverEntry.parse(output)

            if !parsed.isEmpty {
                let servers = Set(parsed.flatMap(\.nameservers))
                var latencies: [String: Double] = [:]
                await withTaskGroup(of: (String, Double?).self) { group in
                    for server in servers {
                        group.addTask { (server, await Self.probe(server)) }
                    }
                    for await (server, ms) in group {
                        if let ms { latencies[server] = ms }
                    }
                }
                for i in parsed.indices {
                    for ns in parsed[i].nameservers {
                        parsed[i].latencyMs[ns] = latencies[ns]
                    }
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.runID == myRun else { return }
                if parsed.isEmpty {
                    self.error = "Could not read DNS configuration."
                } else {
                    self.resolvers = parsed
                    self.lastUpdated = Date()
                }
                self.isRunning = false
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    private nonisolated static func probe(_ server: String) async -> Double? {
        let clock = Date()
        let output = SubprocessRunner.run(executable: "/usr/bin/dig",
                                           arguments: ["@\(server)", "apple.com", "+time=2", "+tries=1", "+short"])
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return Date().timeIntervalSince(clock) * 1000
    }

    deinit { task?.cancel() }
}
