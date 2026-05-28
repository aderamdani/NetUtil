import SwiftUI

struct AboutView: View {
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.5.1"
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 48) {
                // HERO SECTION
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.accentColor.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 160, height: 160)
                        
                        Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 110, height: 110)
                    }
                    
                    VStack(spacing: 6) {
                        Text("NetUtil")
                            .font(.system(size: 40, weight: .bold))
                            .tracking(-1)
                        
                        Text("Professional Network Diagnostics")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    versionBadge
                }
                .padding(.top, 40)
                
                // CORE VALUE PROPOSITION
                Text("A native toolkit built for system administrators and network enthusiasts. Monitor, analyze, and secure your infrastructure with precision.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
                    .lineSpacing(4)
                
                // TOOLKIT LIST (Flat Hierarchy)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Included Diagnostics")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(toolList.enumerated()), id: \.element.1) { index, tool in
                            HStack(spacing: 16) {
                                Image(systemName: tool.0)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24, alignment: .center)
                                Text(tool.1)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            
                            if index < toolList.count - 1 {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
                }
                .frame(maxWidth: 500)
                
                Divider()
                    .padding(.horizontal, 100)
                    .opacity(0.5)
                
                // FOOTER / CREDITS
                VStack(spacing: 24) {
                    HStack(spacing: 24) {
                        LinkButton(title: "GitHub Repository", icon: "code.branch", url: "https://github.com/aderamdani/NetUtil")
                        LinkButton(title: "Acknowledgements", icon: "heart.fill", action: showAck)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Crafted by Ade Ramdani")
                            .font(.subheadline)
                        Text("SwiftUI · Native Swift 6 · Zero Dependencies")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    private var versionBadge: some View {
        HStack(spacing: 12) {
            Text("v\(currentVersion)")
                .font(.system(.subheadline, design: .monospaced).bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            
            if updater.updateReady {
                Button("Install Update") { updater.installAndRelaunch() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
            } else if updater.isDownloading {
                ProgressView(value: updater.downloadProgress)
                    .frame(width: 80)
                    .controlSize(.small)
            }
        }
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
    ]

    private func showAck() {
        let alert = NSAlert()
        alert.messageText = "Acknowledgements"
        alert.informativeText = "System tools: ping, traceroute, whois, dig, netstat.\nFrameworks: SwiftUI, Charts, Network, CoreWLAN, MapKit, CryptoKit.\nData: ipinfo.io"
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }
}

struct LinkButton: View {
    let title: String
    let icon: String
    var url: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button {
            if let urlStr = url, let urlObj = URL(string: urlStr) {
                NSWorkspace.shared.open(urlObj)
            } else {
                action?()
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline)
        }
        .buttonStyle(.bordered)
    }
}
