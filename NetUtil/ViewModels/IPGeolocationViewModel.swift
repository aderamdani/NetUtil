import Foundation
import Observation

@Observable
@MainActor
final class IPGeolocationViewModel {
    var query: String = ""
    private(set) var isRunning = false
    private(set) var error: String?
    private(set) var result: IPGeoResult?
    private(set) var lastQuery: String?

    var onSessionComplete: ((SessionRecord) -> Void)?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let startedAt = Date()

    /// Seeds the view with an already-fetched result (e.g. ToolStore's cached
    /// public-IP lookup) instead of spending another network call.
    func seed(_ result: IPGeoResult) {
        guard self.result == nil else { return }
        self.result = result
        self.lastQuery = "My IP"
    }

    func start() {
        stop()
        error = nil
        isRunning = true
        let target = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = target.isEmpty ? "My IP" : target
        lastQuery = label
        let began = Date()

        task = Task { [weak self] in
            let fetched = await Self.fetch(target: target)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.isRunning = false
                if let fetched {
                    self.result = fetched
                    self.onSessionComplete?(SessionRecord(
                        tool: "IP Geolocation", target: label,
                        summary: "\(fetched.shortLabel) — \(fetched.ispName)",
                        status: .success, duration: Date().timeIntervalSince(began)
                    ))
                } else {
                    self.error = "Could not resolve geolocation for \(target.isEmpty ? "your public IP" : target)."
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    private nonisolated static func fetch(target: String) async -> IPGeoResult? {
        let path = target.isEmpty ? "json"
            : "\(target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? target)/json"
        guard let url = URL(string: "https://ipinfo.io/\(path)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return IPGeoResult.parse(data)
        } catch {
            return nil
        }
    }

    deinit { task?.cancel() }
}
