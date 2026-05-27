import SwiftUI

struct AboutView: View {
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.3.0"
    private let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    @StateObject private var updater = Updater()
    @State private var checkingForUpdates = false
    @State private var showUpdateAlert = false
    @State private var updateAlertTitle = ""
    @State private var updateMessage = ""
    @State private var latestDMGURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 48) {
                // HERO SECTION
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.accentColor.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 160, height: 160)
                        
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 110, height: 110)
                            .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
                    }
                    
                    VStack(spacing: 6) {
                        Text("NetUtil")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .tracking(-1)
                        
                        Text("Professional Network Diagnostics")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    versionBadge
                }
                .padding(.top, 40)
                
                // CORE VALUE PROPOSITION
                Text("A modern, native toolkit built for system administrators and network enthusiasts. Monitor, analyze, and secure your infrastructure with precision.")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 540)
                    .lineSpacing(4)
                
                // TOOLKIT GRID
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: "shippingbox.fill")
                            .foregroundColor(.accentColor)
                        Text("INCLUDED DIAGNOSTICS")
                            .font(.system(size: 11, weight: .black))
                            .kerning(1.5)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 4)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(toolList, id: \.1) { icon, name in
                            AboutToolCard(icon: icon, name: name)
                        }
                    }
                }
                .frame(maxWidth: 600)
                
                Divider()
                    .padding(.horizontal, 100)
                
                // FOOTER / CREDITS
                VStack(spacing: 24) {
                    HStack(spacing: 32) {
                        LinkButton(title: "GitHub Repository", icon: "code.branch", url: "https://github.com/aderamdani/NetUtil")
                        LinkButton(title: "Acknowledgements", icon: "heart.fill", action: showAck)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Crafted with ❤️ by **Ade Ramdani**")
                            .font(.subheadline)
                        Text("Built with SwiftUI · Native Swift 6 · Zero Dependencies")
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
        .alert(updateAlertTitle, isPresented: $showUpdateAlert) {
            if let url = latestDMGURL {
                Button("Download Update") { updater.downloadAndInstall(from: url) }
                Button("Later", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: {
            Text(updateMessage)
        }
    }
    
    private var versionBadge: some View {
        HStack(spacing: 12) {
            Text("v\(currentVersion)")
                .font(.system(.subheadline, design: .monospaced).bold())                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .cornerRadius(8)
            
            if updater.updateReady {
                Button("Open & Install") { updater.installAndRelaunch() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
            } else if updater.isDownloading {
                ProgressView(value: updater.downloadProgress)
                    .frame(width: 80)
                    .controlSize(.small)
            } else {
                Button(action: checkForUpdates) {
                    if checkingForUpdates {
                        ProgressView().controlSize(.mini).scaleEffect(0.6)
                    } else {
                        Label("Update", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(checkingForUpdates)
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
        ("globe",                                  "DNS Lookup"),
        ("magnifyingglass.circle",                 "WHOIS"),
        ("lock.shield",                            "SSL/TLS Inspector"),
        ("network",                                "Network Interfaces"),
        ("wifi",                                   "Wi-Fi Inspector"),
        ("arrow.triangle.branch",                  "Route Table"),
        ("chart.bar.xaxis",                        "Bandwidth Monitor"),
    ]

    private func checkForUpdates() {
        checkingForUpdates = true
        let url = URL(string: "https://api.github.com/repos/aderamdani/NetUtil/releases/latest")!
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                self.checkingForUpdates = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let assets = json["assets"] as? [[String: Any]] else { return }
                
                let latestVersion = tagName.replacingOccurrences(of: "v", with: "")
                if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                    if let dmg = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
                       let dlURL = URL(string: dmg["browser_download_url"] as? String ?? "") {
                        self.updateAlertTitle = "Update Available"
                        self.updateMessage = "NetUtil v\(latestVersion) is ready. Upgrade now?"
                        self.latestDMGURL = dlURL
                        self.showUpdateAlert = true
                    }
                } else {
                    self.updateAlertTitle = "Up to Date"
                    self.updateMessage = "You are running the latest version of NetUtil."
                    self.showUpdateAlert = true
                }
            }
        }.resume()
    }

    private func showAck() {
        let alert = NSAlert()
        alert.messageText = "Acknowledgements"
        alert.informativeText = "System tools: ping, traceroute, whois, dig, netstat.\nFrameworks: SwiftUI, Charts, Network, CoreWLAN, MapKit, CryptoKit.\nData: ipinfo.io"
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }
}

struct AboutToolCard: View {
    let icon: String
    let name: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
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
                .font(.subheadline.bold())
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}
