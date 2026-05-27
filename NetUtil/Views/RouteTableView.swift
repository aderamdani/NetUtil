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
        return filtered.filter {
            $0.destination.lowercased().contains(q) ||
            $0.gateway.lowercased().contains(q) ||
            $0.netif.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. STANDARD HEADER (Fixed Top)
            controlBar
                .padding(.bottom, 24)
            
            VStack(alignment: .leading, spacing: 24) {
                // 2. INTERPRETATION HEADER
                interpretationHeader
                
                // 3. STATS BAR
                statsBar
                
                // 4. ROUTE TABLE
                VStack(alignment: .leading, spacing: 12) {
                    Text("ROUTING ENTRIES")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.secondary)
                        .kerning(1)
                    
                    routeTable
                        .background(Color(.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
                }
            }
        }
        .padding(32)
        .onAppear { load() }
        .sheet(isPresented: $showLearningGuide) {
            routesLearningGuideSheet
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // 1. Static Info (Visual Anchor)
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.accentColor)
                Text("Routing Table")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
            .frame(width: 250, alignment: .leading)

            // 2. Variable Settings (Centered)
            HStack(spacing: 12) {
                Picker("", selection: $showIPv6) {
                    Text("IPv4").tag(false)
                    Text("IPv6").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)

                TextField("Filter...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
            }

            Spacer()

            // 3. Action Group
            Button(action: load) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button { showLearningGuide = true } label: {
                Image(systemName: "book.fill").font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Routes Diagnostic Guide")
        }
    }
    
    private var interpretationHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "map.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("System Routing Policy")
                    .font(.headline)
                Text("Currently displaying \(entries.filter { $0.isIPv6 == showIPv6 }.count) active routes for \(showIPv6 ? "IPv6" : "IPv4").")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .standard))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 8)
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "TOTAL ROUTES", value: "\(entries.count)", icon: "list.bullet.rectangle")
            if let def = entries.first(where: { $0.isDefault && $0.isIPv6 == showIPv6 }) {
                StatCard(title: "DEFAULT GATEWAY", value: def.gateway, icon: "house.fill", color: .blue)
            }
            StatCard(title: "INTERFACES", value: "\(Set(entries.map(\.netif)).count)", icon: "network")
            Spacer()
        }
    }

    private var routeTable: some View {
        Table(displayed) {
            TableColumn("Destination") { r in
                Text(r.destination)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(r.isDefault ? .accentColor : .primary)
                    .bold(r.isDefault)
            }
            TableColumn("Gateway") { r in
                Text(r.gateway)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            TableColumn("Flags") { r in
                Text(r.flags)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .help(flagDescription(r.flags))
            }
            TableColumn("Iface") { r in
                Text(r.netif)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(minHeight: 400)
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
            await MainActor.run {
                entries = result
                lastUpdated = Date()
                isLoading = false
            }
        }
    }

    private static func fetchRoutes() async -> [RouteEntry] {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        p.arguments = ["-rn"]
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
        } catch { return [] }
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
    
    private var routesLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Routes Learning Guide").font(.title2.bold())
                    Text("Learn how your computer decides where to send data.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "The Routing Table", icon: "map") {
                        Text("A routing table is a set of rules that determines where data packets should be directed. Every device on a network has its own routing table.")
                    }
                    GuideSection(title: "Default Gateway", icon: "house.fill") {
                        Text("The 'default' route is where data goes when no other specific rule matches. This is usually your router's IP address.")
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }
}
