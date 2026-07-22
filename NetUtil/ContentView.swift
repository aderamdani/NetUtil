import SwiftUI
import Observation

enum Tool: String, CaseIterable, Identifiable {
    case dashboard   = "Dashboard"
    case doctor      = "Doctor"
    case ping        = "Ping"
    case traceroute  = "Traceroute"
    case multiPing   = "Multi-Ping"
    case portScan    = "Port Scanner"
    case subnetScan  = "Subnet Scanner"
    case httpLatency = "HTTP Latency"
    case pathMTU     = "Path MTU"
    case subnet      = "Subnet Calc"
    case dns         = "DNS Lookup"
    case ssl         = "SSL/TLS"
    case whois       = "WHOIS"
    case bandwidth   = "Bandwidth"
    case interfaces  = "Interfaces"
    case wifi        = "Wi-Fi"
    case routes         = "Routes"
    case neighbors      = "Neighbors"
    case connections    = "Connections"
    case statistics     = "Statistics"
    case speedTest       = "Speed Test"
    case netQuality      = "Net Quality"
    case wakeOnLAN       = "Wake on LAN"
    case portListener    = "Port Listener"
    case ipGeolocation   = "IP Geolocation"
    case dnsResolver     = "DNS Resolver"
    case sessionHistory  = "History"
    case compare         = "Compare"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:    "square.grid.2x2"
        case .doctor:       "stethoscope"
        case .ping:         "antenna.radiowaves.left.and.right"
        case .traceroute:   "point.3.connected.trianglepath.dotted"
        case .multiPing:    "dot.radiowaves.left.and.right"
        case .portScan:     "checklist"
        case .subnetScan:   "network.badge.shield.half.filled"
        case .httpLatency:  "stopwatch"
        case .pathMTU:      "ruler"
        case .subnet:       "number.square"
        case .dns:          "globe"
        case .ssl:          "lock.shield"
        case .whois:        "magnifyingglass.circle"
        case .bandwidth:    "chart.bar.xaxis"
        case .interfaces:   "network"
        case .wifi:         "wifi"
        case .routes:         "arrow.triangle.branch"
        case .neighbors:      "person.2.wave.2"
        case .connections:    "app.connected.to.app.below.fill"
        case .statistics:     "chart.line.uptrend.xyaxis"
        case .speedTest:      "speedometer"
        case .netQuality:     "gauge.with.dots.needle.67percent"
        case .wakeOnLAN:      "power.circle"
        case .portListener:   "ear"
        case .ipGeolocation:  "mappin.and.ellipse"
        case .dnsResolver:    "server.rack"
        case .sessionHistory: "clock.arrow.circlepath"
        case .compare:        "arrow.left.arrow.right"
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
        case .subnetScan:  "1"
        case .whois:       "2"
        case .bandwidth:   "3"
        case .interfaces:  "4"
        case .wifi:        "5"
        case .routes:      "6"
        case .statistics:     "7"
        case .speedTest:      "8"
        case .sessionHistory: "9"
        case .compare:        "0"
        // Both ⌘ digit banks are full; the newest tools have no shortcut.
        case .netQuality, .wakeOnLAN, .doctor, .pathMTU, .neighbors, .connections,
             .portListener, .ipGeolocation, .dnsResolver: nil
        }
    }

    /// First nine tools use plain ⌘; the second bank repeats the digits with ⌥⌘.
    var shortcutModifiers: EventModifiers {
        switch self {
        case .dashboard, .ping, .traceroute, .multiPing, .portScan,
             .httpLatency, .subnet, .dns, .ssl:
            return .command
        case .subnetScan, .whois, .bandwidth, .interfaces, .wifi,
             .routes, .statistics, .speedTest, .sessionHistory, .compare:
            return [.command, .option]
        case .netQuality, .wakeOnLAN, .doctor, .pathMTU, .neighbors, .connections,
             .portListener, .ipGeolocation, .dnsResolver:
            return []
        }
    }
}

struct ContentView: View {
    @State private var selection: Tool? = .dashboard
    @Environment(ToolStore.self) private var tools
    @State private var history = HostHistory.shared
    
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
                        .font(.caption2.weight(.bold))
                    TextField("Search history... (⌘F)", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
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
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
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
                        if !tools.favorites.favorites.isEmpty {
                            Section("Favorites") {
                                ForEach(tools.favorites.favorites) { fav in
                                    FavoriteSidebarItem(fav: fav, selection: $selection, tools: tools)
                                }
                                .onMove { tools.favorites.move(from: $0, to: $1) }
                                .onDelete { idxs in
                                    idxs.map { tools.favorites.favorites[$0].id }.forEach { tools.favorites.remove(id: $0) }
                                }
                            }
                        }

                        Section {
                            sidebarItem(.dashboard)
                            sidebarItem(.doctor)
                            sidebarItem(.sessionHistory)
                            sidebarItem(.compare)
                        }

                        Section("Active Probing") {
                            sidebarItem(.ping)
                            sidebarItem(.traceroute)
                            sidebarItem(.multiPing)
                            sidebarItem(.portScan)
                            sidebarItem(.httpLatency)
                            sidebarItem(.pathMTU)
                        }

                        Section("IP Toolbox") {
                            sidebarItem(.subnetScan)
                            sidebarItem(.subnet)
                            sidebarItem(.wakeOnLAN)
                            sidebarItem(.portListener)
                            sidebarItem(.ipGeolocation)
                        }

                        Section("Lookup & Security") {
                            sidebarItem(.dns)
                            sidebarItem(.dnsResolver)
                            sidebarItem(.ssl)
                            sidebarItem(.whois)
                        }
                        
                        Section("Bandwidth") {
                            sidebarItem(.bandwidth)
                            sidebarItem(.statistics)
                            sidebarItem(.speedTest)
                            sidebarItem(.netQuality)
                        }

                        Section("Network Status") {
                            sidebarItem(.interfaces)
                            sidebarItem(.wifi)
                            sidebarItem(.routes)
                            sidebarItem(.neighbors)
                            sidebarItem(.connections)
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
                        .keyboardShortcut(key, modifiers: tool.shortcutModifiers)
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
        case .subnetScan:  return tools.subnetScan.isRunning
        case .netQuality:  return tools.netQuality.isRunning
        case .doctor:      return tools.doctor.isRunning
        case .pathMTU:     return tools.pathMTU.isRunning
        case .portListener: return tools.portListener.isRunning
        case .ipGeolocation: return tools.ipGeolocation.isRunning
        case .dnsResolver:   return tools.dnsResolver.isRunning
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
        case .doctor:      NetworkDoctorView(vm: tools.doctor)
        case .ping:        PingView(vm: tools.ping)
        case .traceroute:  TracerouteView(vm: tools.traceroute)
        case .dns:         DNSView(vm: tools.dns)
        case .portScan:    PortScanView(vm: tools.portScan)
        case .interfaces:  NetworkInterfaceView(vm: tools.interfaces)
        case .httpLatency: HTTPLatencyView(vm: tools.httpLatency)
        case .pathMTU:     PathMTUView(vm: tools.pathMTU)
        case .multiPing:   MultiPingView(vm: tools.multiPing)
        case .wifi:        WiFiInspectorView(vm: tools.wifi)
        case .routes:      RouteTableView()
        case .neighbors:   NeighborsView(vm: tools.neighbors)
        case .connections: ConnectionsView(vm: tools.connections)
        case .ssl:         SSLInspectorView(vm: tools.ssl)
        case .whois:       WhoisView(vm: tools.whois)
        case .bandwidth:   BandwidthView()
        case .subnet:       SubnetCalculatorView(vm: tools.subnet)
        case .subnetScan:    SubnetScanView(viewModel: tools.subnetScan, selection: $selection)
        case .statistics:    StatisticsView()
        case .speedTest:     SpeedTestView(vm: tools.speedTest)
        case .netQuality:    NetQualityView(vm: tools.netQuality)
        case .wakeOnLAN:     WakeOnLanView(vm: tools.wakeOnLAN)
        case .portListener:  PortListenerView(vm: tools.portListener)
        case .ipGeolocation: IPGeolocationView(vm: tools.ipGeolocation)
        case .dnsResolver:   DNSResolverView(vm: tools.dnsResolver)
        case .sessionHistory: SessionHistoryView(selection: $selection)
        case .compare:       CompareView()
        }
    }
}

// MARK: - Favorites Sidebar Item

struct FavoriteSidebarItem: View {
    let fav: FavoriteHost
    @Binding var selection: Tool?
    let tools: ToolStore
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Label(fav.displayName, systemImage: "star.fill")
                .foregroundColor(.orange)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(fav.host)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                Divider()
                ForEach(favToolActions, id: \.0.rawValue) { tool, label in
                    Button {
                        showPopover = false
                        launchFavorite(tool: tool)
                    } label: {
                        Label(label, systemImage: tool.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                Divider()
                Button(role: .destructive) {
                    showPopover = false
                    tools.favorites.remove(id: fav.id)
                } label: {
                    Label("Remove from Favorites", systemImage: "star.slash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .padding(.bottom, 4)
            }
            .frame(width: 220)
        }
    }

    private let favToolActions: [(Tool, String)] = [
        (.ping,        "Ping"),
        (.traceroute,  "Traceroute"),
        (.portScan,    "Port Scanner"),
        (.dns,         "DNS Lookup"),
        (.httpLatency, "HTTP Latency"),
        (.ssl,         "SSL/TLS"),
    ]

    private func launchFavorite(tool: Tool) {
        switch tool {
        case .ping:        tools.ping.quickLaunchHost = fav.host
        case .traceroute:  tools.traceroute.quickLaunchHost = fav.host
        case .portScan:    tools.portScan.quickLaunchHost = fav.host
        default: break
        }
        selection = tool
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
