import Foundation
import Combine
import Observation

@MainActor
@Observable
final class NetworkInterfaceViewModel {
    private(set) var interfaces: [NetworkInterface] = []
    private(set) var lastUpdated: Date = Date()
    private(set) var defaultGateway: String?

    private var timer: AnyCancellable?

    static let normalInterval: TimeInterval = 3
    static let backgroundInterval: TimeInterval = 15

    init() { refresh(); start() }

    func start(interval: TimeInterval = 3) {
        guard timer == nil else { return }
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func refresh() {
        let fetched = NetworkInterfaceFetcher.fetch()
        interfaces = fetched
        defaultGateway = GatewayParser.getDefaultGateway(for: "en0")
        lastUpdated = Date()
    }
}
