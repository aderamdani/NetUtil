import SwiftUI

struct NeighborsView: View {
    @Bindable var vm: NeighborsViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            moodBar
            ScrollView {
                VStack(spacing: Metrics.spacingXL) {
                    if vm.visibleEntries.isEmpty {
                        ToolStateView.empty(title: "No Neighbors Found",
                                            subtitle: "The ARP table fills as this Mac talks to devices — run a Subnet Scan to populate it.")
                    } else {
                        neighborTable
                    }
                }
                .padding(Metrics.spacingXL)
            }
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Neighbors") }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.spacingMD) {
                HStack(spacing: Metrics.spacingSM) {
                    Image(systemName: "person.2.wave.2")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Neighbors")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Neighbors Tool")

                Spacer()

                Toggle(isOn: $vm.hideNonHosts) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .help("Hide broadcast and multicast entries, showing only real devices.")
                .accessibilityLabel("Hide Broadcast and Multicast Entries")

                if !vm.visibleEntries.isEmpty {
                    ReportMenuButton(
                        onExportPDF: { Exporter.saveNeighborsPDF(entries: vm.visibleEntries) },
                        onExportCSV: {
                            let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                            Exporter.save(string: Exporter.csvString(from: vm.visibleEntries),
                                          defaultName: "NetUtil-Neighbors-\(ts.string(from: Date())).csv",
                                          ext: "csv")
                        }
                    )
                }

                Button { vm.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh now (the table auto-refreshes every 5 seconds).")
                .accessibilityLabel("Refresh Neighbors")

                Button { showLearningGuide = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Show Help Guide")
            }
            .padding(.horizontal, Metrics.spacingXL)
            .padding(.vertical, Metrics.spacingLG)

            Divider()
        }
    }

    private var moodBar: some View {
        let hosts = vm.entries.filter { $0.kind == .host }
        let unresolved = hosts.filter { $0.mac == nil }.count
        let interfaces = Set(hosts.map(\.interface)).count
        let msg = hosts.isEmpty
            ? "The ARP table maps IP addresses to hardware on your local network"
            : "\(hosts.count) device\(hosts.count == 1 ? "" : "s") across \(interfaces) interface\(interfaces == 1 ? "" : "s")"
              + (unresolved > 0 ? "  —  \(unresolved) unresolved" : "")
        return MoodBar(icon: "person.2.wave.2",
                       color: hosts.isEmpty ? .secondary : .accentColor,
                       message: msg)
    }

    // MARK: - Table

    private var neighborTable: some View {
        VStack(spacing: 0) {
            headerRow
            Divider().opacity(0.5)
            ForEach(Array(vm.visibleEntries.enumerated()), id: \.element.id) { idx, entry in
                entryRow(entry)
                if idx < vm.visibleEntries.count - 1 {
                    Divider().opacity(0.5)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            TableHeader("IP Address", width: 140)
            TableHeader("MAC Address", width: 160)
            TableHeader("Interface", width: 80)
            TableHeader("Type", width: 90)
            Spacer()
        }
        .padding(.horizontal, Metrics.spacingLG)
        .padding(.vertical, Metrics.spacingMD)
    }

    private func entryRow(_ entry: ARPEntry) -> some View {
        HStack {
            Text(entry.ip)
                .font(.system(.subheadline, design: .monospaced))
                .frame(width: 140, alignment: .leading)
                .textSelection(.enabled)
            Text(entry.mac ?? "unresolved")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(entry.mac == nil ? .secondary : .primary)
                .frame(width: 160, alignment: .leading)
                .textSelection(.enabled)
            Text(entry.interface)
                .font(.system(.subheadline, design: .monospaced))
                .frame(width: 80, alignment: .leading)
            Text(kindLabel(entry))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, Metrics.spacingLG)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Neighbor \(entry.ip)")
        .accessibilityValue("\(entry.mac ?? "unresolved") on \(entry.interface)")
    }

    private func kindLabel(_ entry: ARPEntry) -> String {
        switch entry.kind {
        case .host:      entry.isPermanent ? "Permanent" : "Device"
        case .broadcast: "Broadcast"
        case .multicast: "Multicast"
        }
    }
}
