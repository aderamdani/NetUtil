import Foundation

struct GatewayParser {
    // nonisolated: spawns netstat and blocks on its output, so callers must be
    // able to run it off the main actor.
    nonisolated static func getDefaultGateway(for interface: String = "en0") -> String? {
        let output = SubprocessRunner.run(executable: "/usr/sbin/netstat", arguments: ["-rn"])
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.split(separator: " ").map { String($0) }
            if parts.count >= 4 && parts[0] == "default" && parts[3] == interface {
                return parts[1]
            }
        }
        return nil
    }

    /// First default route on any interface — used by Connectivity Doctor,
    /// where "which interface" matters less than "is there a way out at all".
    nonisolated static func anyDefaultGateway() -> (gateway: String, interface: String)? {
        let output = SubprocessRunner.run(executable: "/usr/sbin/netstat", arguments: ["-rn"])
        for line in output.components(separatedBy: .newlines) {
            let parts = line.split(separator: " ").map { String($0) }
            if parts.count >= 4 && parts[0] == "default" {
                return (parts[1], parts[3])
            }
        }
        return nil
    }
}
