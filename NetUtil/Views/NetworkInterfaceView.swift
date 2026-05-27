import SwiftUI

struct NetworkInterfaceView: View {
    @ObservedObject var vm: NetworkInterfaceViewModel
    @State private var showAll = false
    @State private var showLearningGuide = false

    private var displayed: [NetworkInterface] { showAll ? vm.interfaces : vm.interfaces.filter { $0.isUp } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar.padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    interpretationHeader
                    statsBar.padding(.bottom, 8)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Active Adapters")
                        LazyVStack(spacing: 12) {
                            ForEach(displayed) { iface in InterfaceDetailCard(iface: iface) }
                            if displayed.isEmpty { emptyState }
                        }
                    }
                }
            }
        }
        .padding(32)
        .onAppear { vm.refresh() }
        .sheet(isPresented: $showLearningGuide) { interfaceLearningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "network").foregroundColor(.accentColor)
                Text("System Interfaces").font(.headline)
            }.padding(.horizontal, 16).frame(height: 38).background(Color.accentColor.opacity(0.1)).cornerRadius(8).frame(width: 250, alignment: .leading)

            HStack(spacing: 12) {
                Toggle("Show Inactive", isOn: $showAll).font(.system(size: 11, weight: .medium)).toggleStyle(.checkbox)
                Divider().frame(height: 20)
                HStack(spacing: 4) {
                    Text("Updated").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    Text(vm.lastUpdated.formatted(date: .omitted, time: .standard)).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: { vm.refresh() }) {
                HStack(spacing: 6) { Image(systemName: "arrow.clockwise"); Text("Refresh") }.font(.system(size: 13, weight: .medium))
            }.buttonStyle(.bordered)

            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View { Text(title).font(.headline).foregroundColor(.primary) }

    private var interpretationHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            let active = vm.interfaces.filter { $0.isUp }.count
            Image(systemName: active > 0 ? "antenna.radiowaves.left.and.right" : "network.slash").font(.title2).foregroundColor(active > 0 ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(active > 0 ? "Network Online" : "Disconnected").font(.headline)
                Text("System has \(active) active network interfaces.").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }.padding(.bottom, 8)
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "Total Adapters", value: "\(vm.interfaces.count)", icon: "laptopcomputer")
            StatCard(title: "Active Up", value: "\(vm.interfaces.filter(\.isUp).count)", icon: "arrow.up.circle.fill", color: .green)
            if let vlan = vm.interfaces.first(where: { $0.isVLAN }) { StatCard(title: "VLAN Active", value: vlan.name, icon: "tag.fill", color: .purple) }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack { Spacer(); Text("No active interfaces found.").font(.headline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, minHeight: 150)
    }
    
    private var interfaceLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Interface Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) { GuideSection(title: "What is an Interface?", icon: "network") { Text("A connection point between your computer and a network.") } }.padding(24) }
        }.frame(width: 500, height: 600)
    }
}

private struct InterfaceDetailCard: View {
    let iface: NetworkInterface
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: iface.typeIcon).foregroundColor(iface.isUp ? (iface.isVLAN ? .purple : .primary) : .secondary).frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(iface.name).font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text(iface.typeName).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                }
                Spacer()
                statusBadge
            }
            Divider().opacity(0.5)
            VStack(alignment: .leading, spacing: 8) {
                if iface.isVLAN {
                    if let tag = iface.vlanTag { ifaceRow(label: "VLAN ID", value: "\(tag)") }
                    if let parent = iface.parentInterface { ifaceRow(label: "Parent", value: parent) }
                }
                if !iface.ipv4.isEmpty { ForEach(iface.ipv4, id: \.self) { ip in ifaceRow(label: "IPv4", value: ip) } }
                if let mac = iface.mac { ifaceRow(label: "MAC", value: mac) }
                if let mtu = iface.mtu { ifaceRow(label: "MTU", value: "\(mtu)") }
            }
        }
        .padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusBadge: some View {
        let (bg, fg, label): (Color, Color, String) = iface.isUp ? (.green.opacity(0.12), .green, "Connected") : (.red.opacity(0.08), .red, "Disconnected")
        return Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(fg).padding(.horizontal, 6).padding(.vertical, 2).background(bg).cornerRadius(4)
    }
    
    private func ifaceRow(label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary).frame(width: 60, alignment: .leading)
            Text(value).font(.system(size: 11, design: .monospaced)).foregroundColor(.primary).textSelection(.enabled)
            Spacer()
            Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string) } label: { Image(systemName: "doc.on.clipboard").font(.system(size: 10)) }.buttonStyle(.plain).foregroundColor(.secondary.opacity(0.5))
        }
    }
}
