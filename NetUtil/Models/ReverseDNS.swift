import Foundation

/// Reverse DNS (PTR) lookup: IP address → hostname, via `dig -x`.
enum ReverseDNS {
    nonisolated static func lookup(_ ip: String) async -> String? {
        let output = await Task.detached(priority: .utility) {
            SubprocessRunner.run(executable: "/usr/bin/dig",
                                 arguments: ["-x", ip, "+short", "+time=2", "+tries=1"])
        }.value
        let name = output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        guard let name else { return nil }
        return name.hasSuffix(".") ? String(name.dropLast()) : name
    }
}
