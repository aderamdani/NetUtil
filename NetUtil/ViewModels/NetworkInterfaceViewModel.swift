import Foundation
import Combine

@MainActor
class NetworkInterfaceViewModel: ObservableObject {
    @Published var interfaces: [NetworkInterface] = []
    @Published var lastUpdated: Date = Date()

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
