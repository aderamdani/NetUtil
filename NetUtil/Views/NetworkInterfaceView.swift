import SwiftUI
import Observation

struct NetworkInterfaceView: View {
    var vm: NetworkInterfaceViewModel
    @State private var showAll = false
    @State private var showLearningGuide = false

    private var active: [NetworkInterface] { vm.interfaces.filter { $0.isUp } }
    private var inactive: [NetworkInterface] { vm.interfaces.filter { !$0.isUp } }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
                    gatewaySection
                    
                    interpretationSection
                    
                    statsBarSection
                    
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Active Adapters", icon: "arrow.up.circle.fill")
                        
                        if active.isEmpty {
                            emptyState(msg: "No Active Interfaces Found")
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(active) { iface in
                                    InterfaceDetailCard(iface: iface)
                                }
                            }
                        }
                    }
                    
                    if showAll && !inactive.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader("Inactive Adapters", icon: "arrow.down.circle.fill")
                            
                            LazyVStack(spacing: 12) {
                                ForEach(inactive) { iface in
                                    InterfaceDetailCard(iface: iface)
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        .onAppear { vm.refresh() }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Network Interfaces") }
    }

    private var gatewaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Gateway Quick Actions", icon: "arrow.triangle.branch")
            
            HStack(spacing: 16) {
                if let gateway = vm.defaultGateway {
                    Text("Gateway: \(gateway)")
                        .font(.system(.body, design: .monospaced))
                    
                    Spacer()
                    
                    Button {
                        // Action for Ping
                    } label: {
                        Label("Ping Gateway", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        // Action for Traceroute
                    } label: {
                        Label("Traceroute Gateway", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("No gateway detected on en0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "network")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Network Interfaces")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Network Interfaces Tool")
                
                Spacer()
                
                HStack(spacing: 16) {
                    Toggle("Show Inactive", isOn: $showAll)
                        .font(.subheadline)
                        .toggleStyle(.checkbox)
                        .accessibilityLabel("Show inactive interfaces")
                    
                    Divider().frame(height: 16)

                    ReportMenuButton(
                        onExportPDF: {},
                        onExportCSV: {
                            let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                            Exporter.save(string: Exporter.csvString(from: vm.interfaces),
                                          defaultName: "NetUtil-Interfaces-\(ts.string(from: Date())).csv",
                                          ext: "csv")
                        }
                    )

                    Button { vm.refresh() } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Refresh interface list")

                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Show Help Guide")
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
        .accessibilityAddTraits(.isHeader)
    }

    private var interpretationSection: some View {
        HStack(alignment: .center, spacing: 16) {
            let count = active.count
            ZStack {
                Circle()
                    .fill((count > 0 ? Color.green : Color.red).opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: count > 0 ? "antenna.radiowaves.left.and.right" : "network.slash")
                    .foregroundColor(count > 0 ? .green : .red)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(count > 0 ? "Network Online" : "System Disconnected")
                    .font(.headline)
                Text("Detected \(count) active and \(inactive.count) standby interfaces.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(count > 0 ? "Network Online. \(count) active interfaces." : "System Disconnected.")
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Last Updated").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                Text(vm.lastUpdated.formatted(date: .omitted, time: .standard))
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Last updated at \(vm.lastUpdated.formatted(date: .omitted, time: .standard))")
        }
    }

    private var statsBarSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Total Adapters", value: "\(vm.interfaces.count)", icon: "laptopcomputer")
                .accessibilityElement(children: .combine)
            StatCard(title: "Active Link", value: "\(active.count)", icon: "arrow.up.circle.fill", color: .green)
                .accessibilityElement(children: .combine)
            if let vlan = vm.interfaces.first(where: { $0.isVLAN }) {
                StatCard(title: "VLAN Active", value: vlan.name, icon: "tag.fill", color: .purple)
                    .accessibilityElement(children: .combine)
            }
            if let mac = active.first?.mac {
                StatCard(title: "Primary MAC", value: String(mac.prefix(8)) + "...", icon: "barcode")
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private func emptyState(msg: String) -> some View {
        VStack(spacing: 12) {
            Text(msg)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        .accessibilityLabel(msg)
    }
}

// REMOVED: InterfaceDetailCard (now in Components/InterfaceDetailCard.swift)

private struct StatusBadge: View {
    let isConnected: Bool
    var body: some View {
        Text(isConnected ? "Connected" : "Disconnected")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isConnected ? Color.green.opacity(0.15) : Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(isConnected ? .green : .red)
    }
}
