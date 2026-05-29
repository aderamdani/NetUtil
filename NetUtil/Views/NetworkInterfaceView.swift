import SwiftUI

struct NetworkInterfaceView: View {
    @ObservedObject var vm: NetworkInterfaceViewModel
    @State private var showAll = false
    @State private var showLearningGuide = false

    private var active: [NetworkInterface] { vm.interfaces.filter { $0.isUp } }
    private var inactive: [NetworkInterface] { vm.interfaces.filter { !$0.isUp } }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
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

    // MARK: - Components

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
                
                Spacer()
                
                HStack(spacing: 16) {
                    Toggle("Show Inactive", isOn: $showAll)
                        .font(.subheadline)
                        .toggleStyle(.checkbox)
                    
                    Divider().frame(height: 16)
                    
                    Button { vm.refresh() } label: {
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
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Last Updated").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                Text(vm.lastUpdated.formatted(date: .omitted, time: .standard))
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
            StatCard(title: "Total Adapters", value: "\(vm.interfaces.count)", icon: "laptopcomputer")
            StatCard(title: "Active Link", value: "\(active.count)", icon: "arrow.up.circle.fill", color: .green)
            if let vlan = vm.interfaces.first(where: { $0.isVLAN }) {
                StatCard(title: "VLAN Active", value: vlan.name, icon: "tag.fill", color: .purple)
            }
            if let mac = active.first?.mac {
                StatCard(title: "Primary MAC", value: String(mac.prefix(8)) + "...", icon: "barcode")
            }
        }
    }

    private func emptyState(msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text(msg)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }
}

private struct InterfaceDetailCard: View {
    let iface: NetworkInterface
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iface.isUp ? (iface.isVLAN ? Color.purple.opacity(0.1) : Color.accentColor.opacity(0.1)) : Color.secondary.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: iface.typeIcon)
                        .foregroundColor(iface.isUp ? (iface.isVLAN ? .purple : .accentColor) : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(iface.name)
                        .font(.system(.headline, design: .monospaced))
                    Text(iface.typeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(isConnected: iface.isUp)
            }
            
            Divider().opacity(0.5)
            
            VStack(alignment: .leading, spacing: 10) {
                if iface.isVLAN {
                    if let tag = iface.vlanTag { ifaceRow(label: "VLAN ID", value: "\(tag)") }
                    if let parent = iface.parentInterface { ifaceRow(label: "Parent", value: parent) }
                }
                
                if !iface.ipv4.isEmpty {
                    ForEach(iface.ipv4, id: \.self) { ip in
                        ifaceRow(label: "IPv4 Addr", value: ip)
                    }
                }
                
                if !iface.ipv6.isEmpty {
                    ForEach(iface.ipv6, id: \.self) { ip in
                        ifaceRow(label: "IPv6 Addr", value: ip)
                    }
                }
                
                if let mac = iface.mac {
                    ifaceRow(label: "MAC Addr", value: mac)
                }
                
                if let mtu = iface.mtu {
                    ifaceRow(label: "MTU Size", value: "\(mtu)")
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func ifaceRow(label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
            
            Spacer()
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary.opacity(0.5))
        }
    }
}

private struct StatusBadge: View {
    let isConnected: Bool
    var body: some View {
        Text(isConnected ? "Connected" : "Disconnected")
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isConnected ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
            .foregroundColor(isConnected ? .green : .red)
            .cornerRadius(4)
    }
}
