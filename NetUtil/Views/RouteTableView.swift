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
        VStack(alignment: .leading, spacing: 0) {
            controlBar.padding(.bottom, 24)
            
            VStack(alignment: .leading, spacing: 32) {
                interpretationHeader
                statsBar.padding(.bottom, 8)
                
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Routing Entries")
                    routeTable.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(32)
        .onAppear { load() }
        .sheet(isPresented: $showLearningGuide) { routesLearningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch").foregroundColor(.accentColor)
                Text("Routing Table").font(.headline)
            }.padding(.horizontal, 16).frame(height: 38).background(Color.accentColor.opacity(0.1)).cornerRadius(8).frame(width: 250, alignment: .leading)

            HStack(spacing: 12) {
                Picker("", selection: $showIPv6) { Text("IPv4").tag(false); Text("IPv6").tag(true) }.pickerStyle(.segmented).frame(width: 120)
                TextField("Filter...", text: $filterText).textFieldStyle(.roundedBorder).frame(width: 150)
            }

            Spacer()

            Button(action: load) {
                HStack(spacing: 6) { Image(systemName: "arrow.clockwise"); Text("Refresh") }.font(.system(size: 13, weight: .medium))
            }.buttonStyle(.bordered)

            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View { Text(title).font(.headline).foregroundColor(.primary) }

    private var interpretationHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "map.fill").font(.title2).foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("System Routing Policy").font(.headline)
                Text("Currently displaying \(entries.filter { $0.isIPv6 == showIPv6 }.count) active routes for \(showIPv6 ? "IPv6" : "IPv4").").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                HStack(spacing: 4) {
                    Text("Updated").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    Text(lastUpdated.formatted(date: .omitted, time: .standard)).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                }
            }
        }.padding(.bottom, 8)
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "Total Routes", value: "\(entries.count)", icon: "list.bullet.rectangle")
            if let def = entries.first(where: { $0.isDefault && $0.isIPv6 == showIPv6 }) { StatCard(title: "Default Gateway", value: def.gateway, icon: "house.fill", color: .blue) }
            StatCard(title: "Interfaces", value: "\(Set(entries.map(\.netif)).count)", icon: "network")
            Spacer()
        }
    }

    private var routeTable: some View {
        Table(displayed) {
            TableColumn("Destination") { r in Text(r.destination).font(.system(size: 11, design: .monospaced)).foregroundColor(r.isDefault ? .primary : .secondary).bold(r.isDefault) }
            TableColumn("Gateway") { r in Text(r.gateway).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary) }
            TableColumn("Flags") { r in Text(r.flags).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).help(flagDescription(r.flags)) }
            TableColumn("Iface") { r in Text(r.netif).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary) }
        }
        .frame(minHeight: 400)
    }

    private func flagDescription(_ flags: String) -> String {
        let map: [(Character, String)] = [("U", "Up"), ("G", "Gateway"), ("H", "Host"), ("S", "Static"), ("D", "Dynamic"), ("M", "Modified"), ("C", "Cloning"), ("W", "WasCloned"), ("L", "Link"), ("R", "Reject"), ("B", "Blackhole"), ("I", "Interface")]
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
    
    private var routesLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Routes Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) { GuideSection(title: "The Routing Table", icon: "map") { Text("Rules for where data packets go.") } }.padding(24) }
        }.frame(width: 500, height: 600)
    }
}
