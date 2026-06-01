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

    init() {
        refresh()
        timer = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        let fetched = NetworkInterfaceFetcher.fetch()
        interfaces = fetched
        defaultGateway = GatewayParser.getDefaultGateway(for: "en0")
        lastUpdated = Date()
    }
}
