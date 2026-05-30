import Foundation
import Combine
import Observation

@MainActor
@Observable
final class NetworkInterfaceViewModel {
    var interfaces: [NetworkInterface] = []
    var lastUpdated: Date = Date()

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
        lastUpdated = Date()
    }
}
