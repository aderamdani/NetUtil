import Foundation
import Observation

@Observable
@MainActor
final class SubnetScanViewModel {
    var cidrInput: String = "192.168.1.0/24"
    var results: [SubnetScanResult] = []
    var isScanning: Bool = false
    var progress: Double = 0.0
    var batchSize: Int = 16
    var filterMode: FilterMode = .aliveOnly
    var sortKey: SortKey = .ip
    var scanDuration: String = "0.0s"
    
    enum FilterMode: String, CaseIterable {
        case all = "All", aliveOnly = "Alive Only", unreachableOnly = "Unreachable Only"
    }
    enum SortKey { case ip, rtt, hostname }
    
    private(set) var scanStats: (total: Int, alive: Int, unreachable: Int) = (0, 0, 0)

    var filteredResults: [SubnetScanResult] {
        var items = results
        switch filterMode {
        case .aliveOnly: items = items.filter { $0.status == .alive }
        case .unreachableOnly: items = items.filter { $0.status == .unreachable }
        case .all: break
        }
        
        return items.sorted {
            switch sortKey {
            case .ip: return $0.ip.compare($1.ip, options: .numeric) == .orderedAscending
            case .rtt: return ($0.rtt ?? 9999) < ($1.rtt ?? 9999)
            case .hostname: return ($0.hostname ?? "z") < ($1.hostname ?? "z")
            }
        }
    }

    func startScan() async {
        guard !isScanning else { return }
        let start = Date()
        let components = cidrInput.split(separator: "/")
        guard components.count == 2,
              let prefix = Int(components[1]),
              let subnet = NetworkMath.calculateSubnet(ip: String(components[0]), prefix: prefix) else { return }
        
        let hosts = generateIPs(network: subnet.networkAddress, prefix: prefix)
        isScanning = true
        results = hosts.map { SubnetScanResult(ip: $0, status: .scanning) }
        scanStats = (hosts.count, 0, 0)
        progress = 0.0
        
        for batchStart in stride(from: 0, to: hosts.count, by: batchSize) {
            guard isScanning else { break }
            let batch = Array(hosts[batchStart..<min(batchStart + batchSize, hosts.count)])
            
            await withTaskGroup(of: (String, Double?).self) { group in
                for ip in batch { group.addTask { await self.pingSingle(ip) } }
                for await (ip, rtt) in group {
                    if let idx = self.results.firstIndex(where: { $0.ip == ip }) {
                        self.results[idx].status = rtt != nil ? .alive : .unreachable
                        self.results[idx].rtt = rtt
                    }
                }
            }
            self.progress = Double(min(batchStart + batchSize, hosts.count)) / Double(hosts.count)
            self.updateStats()
            self.scanDuration = String(format: "%.1fs", Date().timeIntervalSince(start))
        }
        
        if isScanning {
            await finalizeScan()
        }
        isScanning = false
    }

    private func finalizeScan() async {
        enrichWithARP()
        for i in 0..<results.count {
            if results[i].status == .alive {
                results[i].hostname = await resolveHostname(results[i].ip)
            }
        }
    }

    private func resolveHostname(_ ip: String) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/host")
        process.arguments = [ip]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if let range = output.range(of: "pointer ") {
            let host = String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ".", with: "")
            return host
        }
        return nil
    }

    private func enrichWithARP() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        process.arguments = ["-an"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        for i in 0..<results.count {
            if let range = output.range(of: "(\(results[i].ip)) at ") {
                let substring = output[range.upperBound...]
                if let end = substring.firstIndex(of: " ") {
                    results[i].macAddress = String(substring[..<end])
                }
            }
        }
    }

    private nonisolated func pingSingle(_ ip: String) async -> (String, Double?) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-t", "2", ip]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return (ip, nil)
        }

        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        for line in output.components(separatedBy: CharacterSet.newlines) {
            if line.contains("bytes from") && line.contains("time") {
                if let range = line.range(of: #"time[=<](\d+\.?\d*)"#, options: .regularExpression) {
                    let match = String(line[range])
                    let numStr = match
                        .replacingOccurrences(of: "time=", with: "")
                        .replacingOccurrences(of: "time<", with: "")
                    if let rtt = Double(numStr) {
                        return (ip, rtt)
                    }
                }
            }
        }

        return (ip, nil)
    }

    func stopScan() { isScanning = false }

    private func generateIPs(network: String, prefix: Int) -> [String] {
        guard let start = IPv4Address(network) else { return [] }
        let count = prefix >= 31 ? 0 : (1 << (32 - prefix)) - 2
        var ips: [String] = []
        for i in 1...count {
            ips.append(IPv4Address(start.value + UInt32(i)).string)
        }
        return ips
    }
    
    private func updateStats() {
        let alive = results.filter { $0.status == .alive }.count
        scanStats = (results.count, alive, results.count - alive)
    }
}
