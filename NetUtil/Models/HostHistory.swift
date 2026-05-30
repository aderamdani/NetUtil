import Foundation
import Observation

@Observable
final class HostHistory {
    static let shared = HostHistory()

    private(set) var hosts: [String] = []

    private let key = "netutil.hostHistory"
    private let limit = 20

    private init() {
        hosts = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func record(_ host: String) {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var updated = hosts.filter { $0 != trimmed }
        updated.insert(trimmed, at: 0)
        if updated.count > limit { updated = Array(updated.prefix(limit)) }
        hosts = updated
        UserDefaults.standard.set(updated, forKey: key)
    }

    func remove(_ host: String) {
        hosts.removeAll { $0 == host }
        UserDefaults.standard.set(hosts, forKey: key)
    }

    func clear() {
        hosts = []
        UserDefaults.standard.removeObject(forKey: key)
    }
}
