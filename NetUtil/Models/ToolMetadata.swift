import Foundation

/// Sidebar grouping. Declaration order is display order; `.core` renders
/// as an untitled section, matching the long-standing sidebar layout.
enum ToolGroup: String, CaseIterable {
    case core
    case activeProbing
    case ipToolbox
    case lookupSecurity
    case bandwidth
    case networkStatus

    /// Section header. `nil` renders an untitled section (Core).
    var title: String? {
        switch self {
        case .core:           return nil
        case .activeProbing:  return "Active Probing"
        case .ipToolbox:      return "IP Toolbox"
        case .lookupSecurity: return "Lookup & Security"
        case .bandwidth:      return "Bandwidth"
        case .networkStatus:  return "Network Status"
        }
    }

    /// Tools in this group, in sidebar order.
    var tools: [Tool] { Tool.allCases.filter { $0.group == self } }
}

extension Tool {
    /// Stable persistence token — never changes when the label changes.
    /// Matches the `SessionRecord.tool` keys ViewModels already log, so
    /// existing session history carries over (see `migratedSessionKey`).
    var persistenceKey: String {
        switch self {
        case .dashboard:      return "dashboard"
        case .doctor:         return "doctor"
        case .ping:           return "ping"
        case .traceroute:     return "traceroute"
        case .multiPing:      return "multiPing"
        case .portScan:       return "portScan"
        case .subnetScan:     return "subnetScan"
        case .httpLatency:    return "httpLatency"
        case .pathMTU:        return "pathMTU"
        case .subnet:         return "subnet"
        case .dns:            return "dns"
        case .ssl:            return "ssl"
        case .whois:          return "whois"
        case .bandwidth:      return "bandwidth"
        case .interfaces:     return "interfaces"
        case .wifi:           return "wifi"
        case .routes:         return "routes"
        case .neighbors:      return "neighbors"
        case .connections:    return "connections"
        case .statistics:     return "statistics"
        case .speedTest:      return "speedTest"
        case .netQuality:     return "netQuality"
        case .wakeOnLAN:      return "wakeOnLAN"
        case .portListener:   return "portListener"
        case .ipGeolocation:  return "ipGeolocation"
        case .dnsResolver:    return "dnsResolver"
        case .sessionHistory: return "sessionHistory"
        case .compare:        return "compare"
        }
    }

    /// Display label. Identical to `rawValue` today; separated so a future
    /// rename never breaks persisted state.
    var displayName: String { rawValue }

    var group: ToolGroup {
        switch self {
        case .dashboard, .doctor, .sessionHistory, .compare:
            return .core
        case .ping, .traceroute, .multiPing, .portScan, .httpLatency, .pathMTU:
            return .activeProbing
        case .subnetScan, .subnet, .wakeOnLAN, .portListener, .ipGeolocation:
            return .ipToolbox
        case .dns, .dnsResolver, .ssl, .whois:
            return .lookupSecurity
        case .bandwidth, .statistics, .speedTest, .netQuality:
            return .bandwidth
        case .interfaces, .wifi, .routes, .neighbors, .connections:
            return .networkStatus
        }
    }

    /// Core tools back app-wide state (dashboard shell, daily totals,
    /// session log) and cannot be disabled.
    var canBeDisabled: Bool {
        switch self {
        case .dashboard, .statistics, .sessionHistory:
            return false
        default:
            return true
        }
    }

    init?(persistenceKey: String) {
        guard let match = Tool.allCases.first(where: { $0.persistenceKey == persistenceKey }) else {
            return nil
        }
        self = match
    }

    /// One-time migration for the single legacy session key. Every other
    /// ViewModel already logs `persistenceKey`.
    static func migratedSessionKey(_ key: String) -> String {
        key == "IP Geolocation" ? Tool.ipGeolocation.persistenceKey : key
    }

    /// Pure fallback: a selection pointing at a disabled tool resolves to
    /// the dashboard (which is always available).
    static func fallbackSelection(current: Tool?, availableKeys: Set<String>) -> Tool? {
        guard let current else { return nil }
        return availableKeys.contains(current.persistenceKey) ? current : .dashboard
    }
}
