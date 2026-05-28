import SwiftUI

enum Tool: String, CaseIterable, Identifiable {
    case dashboard   = "Dashboard"
    case ping        = "Ping"
    case traceroute  = "Traceroute"
    case multiPing   = "Multi-Ping"
    case portScan    = "Port Scanner"
    case httpLatency = "HTTP Latency"
    case subnet      = "Subnet Calc"
    case dns         = "DNS Lookup"
    case ssl         = "SSL/TLS"
    case whois       = "WHOIS"
    case bandwidth   = "Bandwidth"
    case interfaces  = "Interfaces"
    case wifi        = "Wi-Fi"
    case routes        = "Routes"
    case networkGuide  = "Network Guide"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:    "square.grid.2x2"
        case .ping:         "antenna.radiowaves.left.and.right"
        case .traceroute:   "point.3.connected.trianglepath.dotted"
        case .dns:          "globe"
        case .portScan:     "checklist"
        case .interfaces:   "network"
        case .httpLatency:  "stopwatch"
        case .multiPing:    "dot.radiowaves.left.and.right"
        case .wifi:         "wifi"
        case .routes:       "arrow.triangle.branch"
        case .ssl:          "lock.shield"
        case .whois:        "magnifyingglass.circle"
        case .bandwidth:    "chart.bar.xaxis"
        case .subnet:       "number.square"
        case .networkGuide: "books.vertical"
        }
    }
    
    var shortcut: KeyEquivalent? {
        switch self {
        case .dashboard:   "1"
        case .ping:        "2"
        case .traceroute:  "3"
        case .multiPing:   "4"
        case .portScan:    "5"
        case .httpLatency: "6"
        case .subnet:      "7"
        case .dns:         "8"
        case .ssl:         "9"
        default:           nil
        }
    }
}

struct ContentView: View {
    @State private var selection: Tool? = .dashboard
    @EnvironmentObject private var tools: ToolStore
    @StateObject private var history = HostHistory.shared
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var filteredHistory: [String] {
        guard !searchText.isEmpty else { return [] }
        return history.hosts.filter { $0.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Global Search Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11, weight: .bold))
                    TextField("Search history... (⌘F)", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($isSearchFocused)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Divider().opacity(0.1)

                if !searchText.isEmpty {
                    List {
                        Section("History Results") {
                            ForEach(filteredHistory, id: \.self) { host in
                                Button {
                                    copyToActiveTool(host)
                                    searchText = ""
                                    isSearchFocused = false
                                } label: {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(.secondary)
                                        Text(host)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            if filteredHistory.isEmpty {
                                Text("No matches found").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    List(selection: $selection) {
                        Section {
                            sidebarItem(.dashboard)
                        }
                        
                        Section("Active Probing") {
                            sidebarItem(.ping)
                            sidebarItem(.traceroute)
                            sidebarItem(.multiPing)
                            sidebarItem(.portScan)
                            sidebarItem(.httpLatency)
                        }

                        Section("IP Toolbox") {
                            sidebarItem(.subnet)
                        }
                        
                        Section("Lookup & Security") {
                            sidebarItem(.dns)
                            sidebarItem(.ssl)
                            sidebarItem(.whois)
                        }
                        
                        Section("Network Status") {
                            sidebarItem(.bandwidth)
                            sidebarItem(.interfaces)
                            sidebarItem(.wifi)
                            sidebarItem(.routes)
                        }

                        Section("Reference") {
                            sidebarItem(.networkGuide)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 175, ideal: 200, max: 240)
        } detail: {
            if let selection {
                toolView(selection)
                    .navigationTitle(selection == .dashboard ? "NetUtil" : "NetUtil — \(selection.rawValue)")
                    .transition(.opacity)
                    .id(selection)
            } else {
                AboutView()
                    .navigationTitle("NetUtil")
            }
        }
        .frame(minWidth: 1000, minHeight: 650)
        .background {
            // Invisible buttons for keyboard shortcuts
            ForEach(Tool.allCases) { tool in
                if let key = tool.shortcut {
                    Button("") { selection = tool }
                        .keyboardShortcut(key, modifiers: .command)
                        .opacity(0)
                }
            }
            
            // Cmd+F shortcut
            Button("") { isSearchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
        }
    }
    
    @ViewBuilder
    private func sidebarItem(_ tool: Tool) -> some View {
        HStack(spacing: 8) {
            Label(tool.rawValue, systemImage: tool.icon)
            Spacer()
            if isToolActive(tool) {
                SidebarActivityIndicator()
            }
        }
        .tag(tool)
    }
    
    private func isToolActive(_ tool: Tool) -> Bool {
        switch tool {
        case .ping:        return tools.ping.isRunning
        case .traceroute:  return tools.traceroute.isRunning
        case .multiPing:   return tools.multiPing.slots.contains { $0.isRunning }
        case .portScan:    return tools.portScan.isRunning
        case .httpLatency: return tools.httpLatency.isRunning
        default:           return false
        }
    }
    
    private func copyToActiveTool(_ host: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(host, forType: .string)
    }
    
    @ViewBuilder
    private func toolView(_ tool: Tool) -> some View {
        switch tool {
        case .dashboard:   DashboardView(selection: $selection)
        case .ping:        PingView(vm: tools.ping)
        case .traceroute:  TracerouteView(vm: tools.traceroute)
        case .dns:         DNSView(vm: tools.dns)
        case .portScan:    PortScanView(vm: tools.portScan)
        case .interfaces:  NetworkInterfaceView(vm: tools.interfaces)
        case .httpLatency: HTTPLatencyView(vm: tools.httpLatency)
        case .multiPing:   MultiPingView(vm: tools.multiPing)
        case .wifi:        WiFiInspectorView(vm: tools.wifi)
        case .routes:      RouteTableView()
        case .ssl:         SSLInspectorView(vm: tools.ssl)
        case .whois:       WhoisView(vm: tools.whois)
        case .bandwidth:   BandwidthView()
        case .subnet:       SubnetCalculatorView(vm: tools.subnet)
        case .networkGuide: NetworkGuideView()
        }
    }
}

struct SidebarActivityIndicator: View {
    @State private var pulse = false
    
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
            .overlay(
                Circle()
                    .stroke(Color.green.opacity(0.5), lineWidth: 2)
                    .scaleEffect(pulse ? 2.5 : 1.0)
                    .opacity(pulse ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
    }
}
