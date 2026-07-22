import Foundation
import Network
import Observation

struct ListenerEvent: Identifiable {
    let id = UUID()
    let time: Date
    let remote: String
    let detail: String
}

@Observable
@MainActor
final class PortListenerViewModel {
    enum Proto: String, CaseIterable, Identifiable {
        case tcp = "TCP"
        case udp = "UDP"
        var id: String { rawValue }
    }

    var port: Int = 8080
    var proto: Proto = .tcp
    private(set) var isRunning = false
    private(set) var error: String?
    private(set) var events: [ListenerEvent] = []

    private static let eventLimit = 200

    @ObservationIgnored nonisolated(unsafe) private var listener: NWListener?

    deinit { listener?.cancel() }

    func start() {
        stop()
        error = nil
        events = []
        guard (1...65535).contains(port) else {
            error = "Port must be between 1 and 65535"
            return
        }
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            error = "Invalid port"
            return
        }

        let params: NWParameters = proto == .tcp ? .tcp : .udp
        params.allowLocalEndpointReuse = true

        let l: NWListener
        do {
            l = try NWListener(using: params, on: nwPort)
        } catch {
            self.error = "Could not open port \(port): \(error.localizedDescription)"
            return
        }

        l.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.isRunning = true
                case .failed(let err):
                    self.error = "Listener failed: \(err.localizedDescription) — the port may be in use."
                    self.stop()
                default:
                    break
                }
            }
        }

        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global())
            conn.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, _, _ in
                let remote = Self.describe(endpoint: conn.endpoint)
                let bytes = data?.count ?? 0
                conn.cancel()
                Task { @MainActor [weak self] in
                    self?.log(remote: remote,
                              detail: bytes > 0 ? "\(bytes) bytes received" : "connected, no data")
                }
            }
        }

        listener = l
        l.start(queue: .global())
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func log(remote: String, detail: String) {
        events.insert(ListenerEvent(time: Date(), remote: remote, detail: detail), at: 0)
        if events.count > Self.eventLimit {
            events.removeLast(events.count - Self.eventLimit)
        }
    }

    private nonisolated static func describe(endpoint: NWEndpoint) -> String {
        if case .hostPort(let host, let port) = endpoint {
            return "\(host):\(port)"
        }
        return "\(endpoint)"
    }
}
