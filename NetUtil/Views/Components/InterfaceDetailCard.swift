import SwiftUI

struct InterfaceDetailCard: View {
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Interface \(iface.name), Status: \(iface.isUp ? "Connected" : "Disconnected")")
            
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
                .font(.system(size: 10, weight: .bold))
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
            .accessibilityLabel("Copy \(label) to clipboard")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct StatusBadge: View {
    let isConnected: Bool
    var body: some View {
        Text(isConnected ? "Connected" : "Disconnected")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isConnected ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
            .foregroundColor(isConnected ? .green : .red)
            .cornerRadius(4)
    }
}
