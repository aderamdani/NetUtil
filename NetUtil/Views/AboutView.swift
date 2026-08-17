import SwiftUI

struct AboutView: View {
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4.11.1"
    private var updater = Updater.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 48) {
                logoHeader
                
                AboutToolGrid(tools: toolList)
                
                footerSection
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }

    private var logoHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "network") // Simplified to SF Symbol for icon
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(radius: 4)
                .foregroundColor(.accentColor)
                .accessibilityLabel("NetUtil Application Icon")
            
            VStack(spacing: 4) {
                Text("NetUtil")
                    .font(.system(.title, design: .default).weight(.bold))
                Text("Version \(currentVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("NetUtil Version \(currentVersion)")
        }
        .padding(.top, 40)
    }

    private var footerSection: some View {
        VStack(spacing: 24) {
            Divider()
            
            HStack(spacing: 40) {
                Button("Check for Updates") {
                    updater.checkForUpdates()
                }
                .buttonStyle(.glassProminent)
                .disabled(updater.isChecking)
                .accessibilityLabel("Check for software updates")
                
                Button("Acknowledgements") {
                    showAck()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Show software acknowledgements")
            }
            
            VStack(spacing: 8) {
                Text("© 2026 Ade Ramdani. All rights reserved.")
                Text("Handcrafted for macOS with SwiftUI & Zero Dependencies.")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
        }
        .padding(.bottom, 60)
    }

    private let toolList: [(String, String)] = [
        ("square.grid.2x2",                       "Dashboard"),
        ("stethoscope",                            "Doctor"),
        ("antenna.radiowaves.left.and.right",      "Ping"),
        ("point.3.connected.trianglepath.dotted",  "Traceroute"),
        ("dot.radiowaves.left.and.right",          "Multi-Ping"),
        ("checklist",                              "Port Scanner"),
        ("network.badge.shield.half.filled",       "Subnet Scanner"),
        ("stopwatch",                              "HTTP Latency"),
        ("ruler",                                  "Path MTU"),
        ("number.square",                          "Subnet Calc"),
        ("globe",                                  "DNS Lookup"),
        ("lock.shield",                            "SSL/TLS"),
        ("magnifyingglass.circle",                 "WHOIS"),
        ("chart.bar.xaxis",                        "Bandwidth"),
        ("network",                                "Interfaces"),
        ("wifi",                                   "Wi-Fi"),
        ("arrow.triangle.branch",                  "Routes"),
        ("person.2.wave.2",                        "Neighbors"),
        ("app.connected.to.app.below.fill",        "Connections"),
        ("chart.line.uptrend.xyaxis",              "Statistics"),
        ("speedometer",                            "Speed Test"),
        ("gauge.with.dots.needle.67percent",       "Net Quality"),
        ("power.circle",                           "Wake on LAN"),
        ("ear",                                    "Port Listener"),
        ("mappin.and.ellipse",                     "IP Geolocation"),
        ("server.rack",                            "DNS Resolver"),
        ("clock.arrow.circlepath",                 "History"),
        ("arrow.left.arrow.right",                 "Compare")
    ]

    private func showAck() {
        let alert = NSAlert()
        alert.messageText = "Acknowledgements"
        alert.informativeText = "System tools: ping, traceroute, whois, dig, netstat.\nFrameworks: SwiftUI, Charts, Network, CoreWLAN, MapKit, CryptoKit.\nData: ipinfo.io"
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }
}
