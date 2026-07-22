import Foundation
import Observation

@Observable
@MainActor
final class ConnectionsViewModel {
    enum StateFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case established = "Established"
        case listening = "Listening"
        var id: String { rawValue }
    }

    private(set) var connections: [NetConnection] = []
    private(set) var lastUpdated: Date?
    var filterText = ""
    var stateFilter: StateFilter = .all

    @ObservationIgnored private var timer: Timer?

    var visibleConnections: [NetConnection] {
        connections.filter { conn in
            switch stateFilter {
            case .all: break
            case .established: guard conn.state == "ESTABLISHED" else { return false }
            case .listening: guard conn.isListening else { return false }
            }
            guard !filterText.isEmpty else { return true }
            let q = filterText.lowercased()
            return conn.command.lowercased().contains(q)
                || conn.local.lowercased().contains(q)
                || (conn.remote?.lowercased().contains(q) ?? false)
        }
        .sorted { ($0.command.lowercased(), $0.pid) < ($1.command.lowercased(), $1.pid) }
    }

    func refresh() {
        Task.detached { [weak self] in
            let output = SubprocessRunner.run(executable: "/usr/sbin/lsof",
                                              arguments: ["-i", "-n", "-P"])
            let parsed = NetConnection.parse(output)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.connections = parsed
                self.lastUpdated = Date()
            }
        }
    }

    /// View-scoped polling — started on appear, stopped on disappear.
    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
