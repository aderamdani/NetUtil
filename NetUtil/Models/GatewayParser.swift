import Foundation

struct GatewayParser {
    // nonisolated: spawns netstat and blocks on its output, so callers must be
    // able to run it off the main actor.
    nonisolated static func getDefaultGateway(for interface: String = "en0") -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-rn"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: " ").map { String($0) }
                if parts.count >= 4 && parts[0] == "default" && parts[3] == interface {
                    return parts[1]
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
