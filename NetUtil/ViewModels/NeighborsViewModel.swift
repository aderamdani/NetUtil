import Foundation
import Observation

@Observable
@MainActor
final class NeighborsViewModel {
    private(set) var entries: [ARPEntry] = []
    private(set) var lastUpdated: Date?
    var hideNonHosts = true

    @ObservationIgnored private var timer: Timer?

    var visibleEntries: [ARPEntry] {
        let items = hideNonHosts ? entries.filter { $0.kind == .host } : entries
        return items.sorted { a, b in
            a.ip.compare(b.ip, options: .numeric) == .orderedAscending
        }
    }

    func refresh() {
        Task.detached { [weak self] in
            let output = SubprocessRunner.run(executable: "/usr/sbin/arp", arguments: ["-an"])
            let parsed = ARPEntry.parse(output)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.entries = parsed
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
