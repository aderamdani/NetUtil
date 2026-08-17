import SwiftUI
import Observation

struct MenuBarView: View {
    @Environment(ToolStore.self) private var tools
    @Environment(NetworkInterfaceViewModel.self) private var networkInterfaces

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader
            Divider()
            bandwidthSection
            Divider()
            footerSection
        }
        .frame(width: 280)
        .onAppear {
            if tools.externalIP == "Checking..." || tools.externalIP == "Unknown" {
                tools.refreshGlobalStatus()
            }
        }
    }

    // MARK: - Helpers

    private var primaryInterface: NetworkInterface? {
        NetworkInterface.primary(in: networkInterfaces.interfaces)
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ipRow(label: "External", value: tools.externalIP,
                      faded: tools.externalIP == "Checking..." || tools.externalIP == "Unknown")
                ipRow(label: "Local",
                      value: primaryInterface?.ipv4.first ?? "—",
                      faded: primaryInterface == nil)
                if !tools.currentConnectionName.isEmpty {
                    ipRow(label: "Network", value: tools.currentConnectionName, faded: false)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if tools.isVPNActive {
                    Label("VPN", systemImage: "lock.shield")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if let iface = primaryInterface {
                    HStack(spacing: 4) {
                        Image(systemName: iface.typeIcon).font(.caption2)
                        Text(iface.typeName).font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func ipRow(label: String, value: String, faded: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundColor(faded ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Live Bandwidth

    private var bandwidthSection: some View {
        HStack(spacing: 12) {
            bandwidthStat(label: "Download", value: tools.bandwidth.totalRxBps, icon: "arrow.down", color: .green)
            bandwidthStat(label: "Upload", value: tools.bandwidth.totalTxBps, icon: "arrow.up", color: .blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func bandwidthStat(label: String, value: Double, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2.weight(.bold)).foregroundColor(color)
                Text(label).font(.caption2.weight(.medium)).foregroundColor(.secondary)
            }
            Text(NetworkMath.formatRate(value))
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .accessibilityLabel("\(label) \(NetworkMath.formatRate(value))")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 0) {
            Button {
                NSApplication.showMainWindow()
            } label: {
            Image(systemName: "macwindow")
                .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .help("Open NetUtil")

            Spacer()

            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Settings")

            Divider().frame(height: 12).padding(.horizontal, 10)

            Button {
                Updater.shared.checkForUpdates(interactive: true)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Check for Updates")

            Divider().frame(height: 12).padding(.horizontal, 10)

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("Quit NetUtil")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    @Environment(ToolStore.self) private var tools

    var body: some View {
        if UserDefaults.standard.bool(forKey: "menuBarShowTraffic") {
            HStack(spacing: 3) {
                Image(systemName: "network")
                    .imageScale(.small)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("↓\(NetworkMath.shortRate(tools.bandwidth.totalRxBps))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                    Text("↑\(NetworkMath.shortRate(tools.bandwidth.totalTxBps))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.blue)
                }
            }
        } else {
            Image(systemName: "network")
                .imageScale(.medium)
                .fontWeight(.regular)
        }
    }
}
