import SwiftUI

enum Tool: String, CaseIterable, Identifiable {
    case ping        = "Ping"
    case traceroute  = "Traceroute"
    case dns         = "DNS Lookup"
    case portScan    = "Port Scanner"
    case interfaces  = "Interfaces"
    case httpLatency  = "HTTP Latency"
    case multiPing   = "Multi-Ping"
    case wifi        = "Wi-Fi"
    case routes      = "Routes"
    case ssl         = "SSL/TLS"
    case whois       = "WHOIS"
    case bandwidth   = "Bandwidth"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .ping:       "antenna.radiowaves.left.and.right"
        case .traceroute: "point.3.connected.trianglepath.dotted"
        case .dns:        "globe"
        case .portScan:   "checklist"
        case .interfaces:  "network"
        case .httpLatency: "stopwatch"
        case .multiPing:   "dot.radiowaves.left.and.right"
        case .wifi:        "wifi"
        case .routes:      "arrow.triangle.branch"
        case .ssl:         "lock.shield"
        case .whois:       "magnifyingglass.circle"
        case .bandwidth:   "chart.bar.xaxis"
        }
    }
}

struct ContentView: View {
    @State private var selection: Tool? = .ping

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Active Probing") {
                    ForEach([Tool.ping, .traceroute, .multiPing, .portScan, .httpLatency]) {
                        Label($0.rawValue, systemImage: $0.icon).tag($0)
                    }
                }
                Section("Lookup") {
                    ForEach([Tool.dns, .whois, .ssl]) {
                        Label($0.rawValue, systemImage: $0.icon).tag($0)
                    }
                }
                Section("Network Info") {
                    ForEach([Tool.interfaces, .wifi, .routes, .bandwidth]) {
                        Label($0.rawValue, systemImage: $0.icon).tag($0)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 185, max: 220)
        } detail: {
            switch selection {
            case .ping:
                PingView()
            case .traceroute:
                TracerouteView()
            case .dns:
                DNSView()
            case .portScan:
                PortScanView()
            case .interfaces:
                NetworkInterfaceView()
            case .httpLatency:
                HTTPLatencyView()
            case .multiPing:
                MultiPingView()
            case .wifi:
                WiFiInspectorView()
            case .routes:
                RouteTableView()
            case .ssl:
                SSLInspectorView()
            case .whois:
                WhoisView()
            case .bandwidth:
                BandwidthView()
            case nil:
                ContentUnavailableView(
                    "Select a Tool",
                    systemImage: "network",
                    description: Text("Choose a tool from the sidebar")
                )
            }
        }
        .frame(minWidth: 900, minHeight: 580)
    }
}
