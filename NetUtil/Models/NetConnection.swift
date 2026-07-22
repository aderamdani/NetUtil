import Foundation

/// One socket from `lsof -i -n -P`: which process is talking to which endpoint.
struct NetConnection: Identifiable, Equatable {
    let id = UUID()
    let command: String
    let pid: Int
    let proto: String
    let local: String
    let remote: String?
    let state: String?

    var isListening: Bool { state == "LISTEN" }

    /// Parses `lsof -i -n -P` output. Column layout:
    /// `COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME [ (STATE)]`
    /// where NAME is `local->remote` for connected sockets or `*:port` for listeners.
    nonisolated static func parse(_ output: String) -> [NetConnection] {
        output.components(separatedBy: "\n").compactMap { line in
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 9,
                  parts[0] != "COMMAND",
                  let pid = Int(parts[1]) else { return nil }
            let proto = parts[7]
            guard proto == "TCP" || proto == "UDP" else { return nil }

            let name = parts[8]
            var state: String?
            if parts.count >= 10, parts[9].hasPrefix("("), parts[9].hasSuffix(")") {
                state = String(parts[9].dropFirst().dropLast())
            }

            let endpoints = name.components(separatedBy: "->")
            return NetConnection(command: parts[0],
                                 pid: pid,
                                 proto: proto,
                                 local: endpoints[0],
                                 remote: endpoints.count > 1 ? endpoints[1] : nil,
                                 state: state)
        }
    }
}
