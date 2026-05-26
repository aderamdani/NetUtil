import SwiftUI

struct NetworkInterfaceView: View {
    @EnvironmentObject private var vm: NetworkInterfaceViewModel
    @State private var showAll = false

    private var displayed: [NetworkInterface] {
        showAll ? vm.interfaces : vm.interfaces.filter { $0.isUp }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(displayed) { iface in
                        InterfaceCard(iface: iface)
                    }
                    if displayed.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .onAppear { vm.refresh() }
    }

    private var toolbar: some View {
        HStack {
            Toggle("Show all interfaces", isOn: $showAll)
                .toggleStyle(.checkbox)
                .font(.caption)
            Spacer()
            Text("Updated \(vm.lastUpdated.formatted(date: .omitted, time: .standard))")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            Button {
                vm.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "network.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No active interfaces")
                .foregroundColor(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

private struct InterfaceCard: View {
    let iface: NetworkInterface

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            addresses
            if iface.mac != nil || iface.mtu != nil {
                Divider()
                linkInfo
            }
        }
        .padding(14)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: iface.typeIcon)
                .font(.title2)
                .foregroundColor(iface.isUp ? .accentColor : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(iface.name)
                        .font(.system(.body, design: .monospaced).bold())
                    Text(iface.typeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.quaternaryLabelColor))
                        .cornerRadius(4)
                }
            }

            Spacer()

            Button {
                let addrs = (iface.ipv4 + iface.ipv6).joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(addrs, forType: .string)
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Copy all addresses")
            .opacity((iface.ipv4 + iface.ipv6).isEmpty ? 0 : 1)

            statusBadge
        }
    }

    private var statusBadge: some View {
        let (bg, fg, label): (Color, Color, String) = iface.isUp
            ? (.green.opacity(0.15), .green, "Up")
            : (.red.opacity(0.1), .red, "Down")
        return Text(label)
            .font(.system(.caption, design: .monospaced).bold())
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }

    private var addresses: some View {
        VStack(alignment: .leading, spacing: 6) {
            if iface.ipv4.isEmpty && iface.ipv6.isEmpty {
                row(label: "Address", value: "—")
            }
            ForEach(iface.ipv4, id: \.self) { addr in
                row(label: "IPv4", value: addr)
            }
            ForEach(iface.ipv6, id: \.self) { addr in
                row(label: "IPv6", value: addr)
            }
        }
    }

    private var linkInfo: some View {
        HStack(spacing: 24) {
            if let mac = iface.mac {
                row(label: "MAC", value: mac)
            }
            if let mtu = iface.mtu {
                row(label: "MTU", value: "\(mtu)")
            }
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
