import SwiftUI

struct RouteTableView: View {
    @State private var entries: [RouteEntry] = []
    @State private var showIPv6 = false
    @State private var filterText = ""
    @State private var lastUpdated = Date()
    @State private var isLoading = false
    @State private var showLearningGuide = false

    private var displayed: [RouteEntry] {
        let filtered = entries.filter { $0.isIPv6 == showIPv6 }
        guard !filterText.isEmpty else { return filtered }
        let q = filterText.lowercased()
        return filtered.filter { $0.destination.lowercased().contains(q) || $0.gateway.lowercased().contains(q) || $0.netif.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
                    interpretationSection
                    
                    statsBarSection
                    
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Routing Entries", icon: "list.bullet.rectangle")
                        
                        routeTable
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
                    }
                }
                .padding(24)
            }
        }
        .onAppear { load() }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Route Table") }
    }

    // MARK: - Components

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Routing Table")
                        .font(.headline)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Picker("", selection: $showIPv6) {
                        Text("IPv4").tag(false)
                        Text("IPv6").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.secondary)
                        TextField("Filter destination...", text: $filterText)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                            .frame(width: 150)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
                    
                    Divider().frame(height: 16)
                    
                    Button { load() } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            Divider()
        }
    }
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).font(.system(.caption2, design: .default).weight(.bold))
            Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
        }
    }

    private var interpretationSection: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "map.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("System Routing Policy")
                    .font(.headline)
                Text("Managing \(entries.filter { $0.isIPv6 == showIPv6 }.count) active \(showIPv6 ? "IPv6" : "IPv4") path definitions.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isLoading {
                ProgressView().controlSize(.small).padding(.trailing, 8)
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Last Synced").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                Text(lastUpdated.formatted(date: .omitted, time: .standard))
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private var statsBarSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Total Routes", value: "\(entries.count)", icon: "list.bullet.rectangle")
            if let def = entries.first(where: { $0.isDefault && $0.isIPv6 == showIPv6 }) {
                StatCard(title: "Default Gateway", value: def.gateway, icon: "house.fill", color: .blue)
            }
            StatCard(title: "Interfaces", value: "\(Set(entries.map(\.netif)).count)", icon: "network")
        }
    }

    private var routeTable: some View {
        Table(displayed) {
            TableColumn("Destination") { r in
                HStack(spacing: 8) {
                    if r.isDefault { Image(systemName: "star.fill").foregroundColor(.orange).font(.system(size: 10)) }
                    Text(r.destination)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(r.isDefault ? .primary : .secondary)
                        .bold(r.isDefault)
                }
            }
            TableColumn("Gateway") { r in
                Text(r.gateway)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            TableColumn("Flags") { r in
                Text(r.flags)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .help(flagDescription(r.flags))
            }
            TableColumn("Interface") { r in
                Text(r.netif)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
        }
        .frame(minHeight: 450)
    }

    private func flagDescription(_ flags: String) -> String {
        let map: [(Character, String)] = [
            ("U", "Up"), ("G", "Gateway"), ("H", "Host"), ("S", "Static"),
            ("D", "Dynamic"), ("M", "Modified"), ("C", "Cloning"), ("W", "WasCloned"),
            ("L", "Link"), ("R", "Reject"), ("B", "Blackhole"), ("I", "Interface")
        ]
        let matched = flags.compactMap { ch in map.first { $0.0 == ch }.map { "\($0.0): \($0.1)" } }
        return matched.isEmpty ? flags : matched.joined(separator: "\n")
    }

    private func load() {
        isLoading = true
        Task.detached {
            let result = await Self.fetchRoutes()
            await MainActor.run { entries = result; lastUpdated = Date(); isLoading = false }
        }
    }

    private static func fetchRoutes() async -> [RouteEntry] {
        let p = Process(); let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat"); p.arguments = ["-rn"]
        p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        var results: [RouteEntry] = []
        var isIPv6 = false
        for line in output.components(separatedBy: "\n") {
            if line.contains("Internet6:") { isIPv6 = true; continue }
            if line.contains("Internet:") { isIPv6 = false; continue }
            if line.hasPrefix("Destination") || line.hasPrefix("Routing") || line.isEmpty { continue }
            let cols = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard cols.count >= 4 else { continue }
            results.append(RouteEntry(destination: cols[0], gateway: cols[1], flags: cols[2], netif: cols.count > 5 ? cols[5] : cols[3], isIPv6: isIPv6))
        }
        return results
    }
}
