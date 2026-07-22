import SwiftUI
import Observation

struct MenuBarView: View {
    @Environment(ToolStore.self) private var tools
    @Environment(NetworkInterfaceViewModel.self) private var networkInterfaces

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader
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
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundColor(faded ? .secondary : .primary)
        }
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
    var body: some View {
        Image(systemName: "network")
            .imageScale(.medium)
            .fontWeight(.regular)
    }
}
