import SwiftUI


/// ipconfig-style readout of the primary connection: addresses, gateway, DNS,
/// and Wi-Fi details laid out in two balanced columns so the panel fills its width.
struct DashboardNetworkDetails: View {
    @Environment(ToolStore.self) private var tools


    private var primary: NetworkInterface? {
        NetworkInterface.primary(in: tools.interfaces.interfaces)
    }


    private var dnsServers: [String] {
        tools.dnsResolver.primaryResolver?.nameservers ?? []
    }


    private var publicIPValue: String {
        if let geo = tools.externalIPGeo {
            return "\(tools.externalIP) · \(geo.ispName)"
        }
        return tools.externalIP
    }


    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingLG) {
            SectionHeader(title: "Network Details", icon: "info.circle")


            if let primary {
                HStack(alignment: .top, spacing: Metrics.spacingXXL) {
                    Grid(alignment: .leadingFirstTextBaseline,
                         horizontalSpacing: Metrics.spacingLG,
                         verticalSpacing: Metrics.spacingSM) {
                        groupLabel("This device")
                        detailRow("Interface", "\(primary.name) · \(primary.typeName)")
                        detailRow("IPv4 address", primary.defaultScanCIDR ?? primary.ipv4.first ?? "—")
                        detailRow("Subnet mask", primary.netmasks.first ?? "—")
                        detailRow("Router", tools.interfaces.defaultGateway ?? "—")
                        detailRow("DNS servers", dnsServers.isEmpty ? "—" : dnsServers.joined(separator: ", "))
                        if let v6 = primary.ipv6.first {
                            detailRow("IPv6 address", v6)
                        }
                        detailRow("MAC address", primary.mac ?? "—")
                        detailRow("MTU", primary.mtu.map { "\($0)" } ?? "—")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)


                    Grid(alignment: .leadingFirstTextBaseline,
                         horizontalSpacing: Metrics.spacingLG,
                         verticalSpacing: Metrics.spacingSM) {
                        groupLabel("Internet")
                        detailRow("Public IP", publicIPValue)
                        if let geo = tools.externalIPGeo {
                            detailRow("Location", geo.shortLabel)
                        }
                        if tools.isVPNActive {
                            detailRow("VPN", "Active")
                        }


                        if let wifi = tools.wifi.info {
                            groupLabel("Wi-Fi")
                            detailRow("Network", wifi.ssid ?? "—")
                            if let ch = wifi.channel {
                                detailRow("Channel", "\(ch)\(wifi.band.map { " (\($0))" } ?? "")")
                            }
                            if let rssi = wifi.rssi {
                                detailRow("Signal", "\(rssi) dBm")
                            }
                            if let rate = wifi.transmitRate {
                                detailRow("Tx rate", String(format: "%.0f Mbps", rate))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("Gathering network info…")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Metrics.spacingXL)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG)
                .stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5)
        )
    }


    @ViewBuilder
    private func groupLabel(_ text: String) -> some View {
        GridRow {
            Text(text.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
                .gridCellColumns(2)
                .padding(.top, Metrics.spacingXS)
        }
    }


    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}
