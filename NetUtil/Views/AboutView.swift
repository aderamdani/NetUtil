import SwiftUI

struct AboutView: View {
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.3.0"
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 48) {
                // App Logo and Name
                VStack(spacing: 16) {
                    Image("AppIcon-Internal") // Placeholder logic or actual asset
                        .resizable()
                        .frame(width: 80, height: 80)
                        .cornerRadius(18)
                        .shadow(radius: 4)
                        .overlay(
                            Image(systemName: "network")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                    
                    VStack(spacing: 4) {
                        Text("NetUtil")
                            .font(.system(size: 24, weight: .bold))
                        Text("Version \(currentVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 40)
                
                // Tool Grid
                VStack(alignment: .leading, spacing: 20) {
                    Text("Included Diagnostics")
                        .font(.headline)
                        .padding(.leading, 4)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(toolList.enumerated()), id: \.element.1) { index, tool in
                            HStack(spacing: 12) {
                                Image(systemName: tool.0)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)
                                
                                Text(tool.1)
                                    .font(.subheadline)
                                
                                Spacer()
                            }
                            .padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            
                            if index < toolList.count - 1 {
                                // Grid fills horizontally
                            }
                        }
                    }
                }
                
                // Footer
                VStack(spacing: 24) {
                    Divider()
                    
                    HStack(spacing: 40) {
                        Button("Check for Updates") {
                            updater.checkForUpdates()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(updater.isChecking)
                        
                        Button("Acknowledgements") {
                            showAck()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    VStack(spacing: 8) {
                        Text("© 2026 Ade Ramdani. All rights reserved.")
                        Text("Handcrafted for macOS with SwiftUI & Zero Dependencies.")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }

    private let toolList: [(String, String)] = [
        ("square.grid.2x2",                       "Mission Dashboard"),
        ("antenna.radiowaves.left.and.right",      "Advanced Ping"),
        ("point.3.connected.trianglepath.dotted",  "Traceroute"),
        ("dot.radiowaves.left.and.right",          "Multi-Ping"),
        ("checklist",                              "Port Scanner"),
        ("stopwatch",                              "HTTP Latency"),
        ("number.square",                          "Subnet Calculator"),
        ("globe",                                  "DNS Lookup"),
        ("magnifyingglass.circle",                 "WHOIS"),
        ("lock.shield",                            "SSL/TLS Inspector"),
        ("network",                                "Network Interfaces"),
        ("wifi",                                   "Wi-Fi Inspector"),
        ("arrow.triangle.branch",                  "Route Table"),
        ("chart.bar.xaxis",                        "Bandwidth Monitor"),
        ("chart.line.uptrend.xyaxis",              "Traffic Statistics"),
        ("speedometer",                            "Speed Test"),
        ("list.bullet.rectangle",                  "Top Processes")
    ]

    private func showAck() {
        let alert = NSAlert()
        alert.messageText = "Acknowledgements"
        alert.informativeText = "System tools: ping, traceroute, whois, dig, netstat.\nFrameworks: SwiftUI, Charts, Network, CoreWLAN, MapKit, CryptoKit.\nData: ipinfo.io"
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }
}
