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
    private var gatewayTask: Task<Void, Never>?

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
        interfaces = NetworkInterfaceFetcher.fetch()
        lastUpdated = Date()

        // netstat spawn + routing-table parse is too slow for the main thread;
        // skip if the previous lookup is still in flight.
        guard gatewayTask == nil else { return }
        gatewayTask = Task.detached(priority: .utility) { [weak self] in
            let gateway = GatewayParser.getDefaultGateway(for: "en0")
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.defaultGateway = gateway
                self.gatewayTask = nil
            }
        }
    }
}
