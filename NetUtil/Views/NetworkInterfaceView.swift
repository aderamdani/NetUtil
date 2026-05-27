import SwiftUI

struct NetworkInterfaceView: View {
    @ObservedObject var vm: NetworkInterfaceViewModel
    @State private var showAll = false
    @State private var showLearningGuide = false

    private var displayed: [NetworkInterface] {
        showAll ? vm.interfaces : vm.interfaces.filter { $0.isUp }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. STANDARD HEADER (Fixed Top)
            controlBar
                .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 2. INTERPRETATION HEADER
                    interpretationHeader
                    
                    // 3. STATS BAR
                    statsBar
                    
                    // 4. INTERFACE LIST
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ACTIVE ADAPTERS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.secondary)
                            .kerning(1)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(displayed) { iface in
                                InterfaceDetailCard(iface: iface)
                            }
                            if displayed.isEmpty {
                                emptyState
                            }
                        }
                    }
                }
            }
        }
        .padding(32)
        .onAppear { vm.refresh() }
        .sheet(isPresented: $showLearningGuide) {
            interfaceLearningGuideSheet
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // 1. Static Info (Visual Anchor)
            HStack(spacing: 10) {
                Image(systemName: "network")
                    .foregroundColor(.accentColor)
                Text("System Interfaces")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
            .frame(width: 250, alignment: .leading)

            // 2. Variable Settings (Centered)
            HStack(spacing: 12) {
                Toggle("Show Inactive", isOn: $showAll)
                    .font(.system(size: 11, weight: .bold))
                    .toggleStyle(.checkbox)
                
                Divider().frame(height: 20)
                
                Text("Updated \(vm.lastUpdated.formatted(date: .omitted, time: .standard))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 3. Action Group
            Button(action: { vm.refresh() }) {
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
            .help("Interface Diagnostic Guide")
        }
    }
    
    private var interpretationHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            let active = vm.interfaces.filter { $0.isUp }.count
            Image(systemName: active > 0 ? "antenna.radiowaves.left.and.right" : "network.slash")
                .font(.title2)
                .foregroundColor(active > 0 ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(active > 0 ? "Network Online" : "Disconnected")
                    .font(.headline)
                Text("System has \(active) active network interface\(active == 1 ? "" : "s") currently established.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "TOTAL ADAPTERS", value: "\(vm.interfaces.count)", icon: "laptopcomputer")
            StatCard(title: "ACTIVE UP", value: "\(vm.interfaces.filter(\.isUp).count)", icon: "arrow.up.circle.fill", color: .green)
            if let vpn = vm.interfaces.first(where: { $0.name.starts(with: "utun") && $0.isUp }) {
                StatCard(title: "VPN TUNNEL", value: vpn.name, icon: "lock.shield.fill", color: .blue)
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No active interfaces found.")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    private var interfaceLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Interface Diagnostic Guide").font(.title2.bold())
                    Text("Learn how to interpret network adapter data.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "What is an Interface?", icon: "network") {
                        Text("An interface is a connection point between your computer and a network. It can be physical (Ethernet, Wi-Fi) or virtual (VPN, Loopback).")
                    }
                    
                    GuideSection(title: "IP Addresses", icon: "number") {
                        VStack(alignment: .leading, spacing: 12) {
                            GuidePoint(title: "IPv4", desc: "The standard 32-bit address format (e.g., 192.168.1.1).")
                            GuidePoint(title: "IPv6", desc: "The modern 128-bit address format designed to replace IPv4.")
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }
}

private struct InterfaceDetailCard: View {
    let iface: NetworkInterface

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: iface.typeIcon)
                    .font(.title3)
                    .foregroundColor(iface.isUp ? .accentColor : .secondary)
                    .frame(width: 32, height: 32)
                    .background(iface.isUp ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(iface.name)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text(iface.typeName)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.secondary)
                }

                Spacer()

                statusBadge
            }
            
            Divider().opacity(0.1)
            
            VStack(alignment: .leading, spacing: 10) {
                if !iface.ipv4.isEmpty {
                    ForEach(iface.ipv4, id: \.self) { ip in
                        ifaceRow(icon: "number", label: "IPv4", value: ip)
                    }
                }
                if let mac = iface.mac {
                    ifaceRow(icon: "barcode", label: "MAC", value: mac)
                }
                if let mtu = iface.mtu {
                    ifaceRow(icon: "arrow.up.left.and.arrow.down.right", label: "MTU", value: "\(mtu)")
                }
            }
        }
        .padding(18)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
    }

    private var statusBadge: some View {
        let (bg, fg, label): (Color, Color, String) = iface.isUp
            ? (.green.opacity(0.12), .green, "CONNECTED")
            : (.red.opacity(0.08), .red, "DISCONNECTED")
        return Text(label)
            .font(.system(size: 9, weight: .black))
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .cornerRadius(4)
    }
    
    private func ifaceRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(.secondary).frame(width: 12)
            Text(label.uppercased()).font(.system(size: 9, weight: .black)).foregroundColor(.secondary).frame(width: 40, alignment: .leading)
            Text(value).font(.system(size: 12, design: .monospaced)).foregroundColor(.primary).textSelection(.enabled)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.clipboard").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary.opacity(0.5))
        }
    }
}
