import SwiftUI

struct AboutView: View {
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
    private let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "2"
    
    @StateObject private var updater = Updater()
    @State private var checkingForUpdates = false
    @State private var updateMessage: String?
    @State private var updateAlertTitle = ""
    @State private var showUpdateAlert = false
    @State private var latestDMGURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                VStack(spacing: 4) {
                    Text("NetUtil")
                        .font(.system(size: 22, weight: .bold))
                    
                    HStack(spacing: 6) {
                        Text("Version \(currentVersion) (\(build))")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        if updater.updateReady {
                            Button("Install & Restart") {
                                updater.installAndRelaunch()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                            .tint(.green)
                        } else if updater.isDownloading {
                            HStack(spacing: 8) {
                                ProgressView(value: updater.downloadProgress)
                                    .frame(width: 60)
                                    .controlSize(.small)
                                Text("\(Int(updater.downloadProgress * 100))%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button {
                                checkForUpdates()
                            } label: {
                                if checkingForUpdates {
                                    ProgressView()
                                        .controlSize(.mini)
                                        .scaleEffect(0.6)
                                } else {
                                    Text("Check for Updates")
                                        .font(.system(size: 10, weight: .medium))
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .disabled(checkingForUpdates)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 14) {
                if let error = updater.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                    Divider()
                }

                Text("A professional network diagnostics toolkit for macOS. Monitor, analyze, and debug network connectivity with ease.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Divider()

                // Tool list
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(toolList, id: \.0) { icon, name in
                        HStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .frame(width: 14)
                            Text(name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Divider()

                // Links and credits
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Developed by **Ade Ramdani**")
                            .font(.caption)
                        Text("Built with SwiftUI · macOS 15+ · Zero dependencies")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Button("GitHub") {
                            NSWorkspace.shared.open(URL(string: "https://github.com/aderamdani/NetUtil")!)
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                        Button("Acknowledgements") {
                            showAck()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 360)
        .fixedSize()
        .alert(updateAlertTitle, isPresented: $showUpdateAlert) {
            if let url = latestDMGURL {
                Button("Download & Update") {
                    updater.downloadAndInstall(from: url)
                }
                Button("Later", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: {
            if let message = updateMessage {
                Text(message)
            }
        }
    }

    private func checkForUpdates() {
        checkingForUpdates = true
        
        let url = URL(string: "https://api.github.com/repos/aderamdani/NetUtil/releases/latest")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.checkingForUpdates = false
                
                if let error = error {
                    self.updateAlertTitle = "Error"
                    self.updateMessage = "Failed to check for updates: \(error.localizedDescription)"
                    self.showUpdateAlert = true
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let assets = json["assets"] as? [[String: Any]] else {
                    self.updateAlertTitle = "Check Failed"
                    self.updateMessage = "Could not parse update information from GitHub."
                    self.showUpdateAlert = true
                    return
                }
                
                let latestVersion = tagName.replacingOccurrences(of: "v", with: "")
                
                // Find DMG asset
                if let dmgAsset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
                   let downloadURLString = dmgAsset["browser_download_url"] as? String,
                   let downloadURL = URL(string: downloadURLString) {
                    
                    if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                        self.updateAlertTitle = "Update Available"
                        self.updateMessage = "A new version (v\(latestVersion)) is available. Would you like to update automatically?"
                        self.latestDMGURL = downloadURL
                    } else {
                        self.updateAlertTitle = "Up to Date"
                        self.updateMessage = "NetUtil v\(currentVersion) is currently the newest version."
                        self.latestDMGURL = nil
                    }
                } else {
                    self.updateAlertTitle = "Check Failed"
                    self.updateMessage = "No installer found for the latest version."
                    self.latestDMGURL = nil
                }
                self.showUpdateAlert = true
            }
        }.resume()
    }

    private let toolList: [(String, String)] = [
        ("square.grid.2x2", "Dashboard"),
        ("antenna.radiowaves.left.and.right", "Ping"),
        ("point.3.connected.trianglepath.dotted", "Traceroute"),
        ("dot.radiowaves.left.and.right", "Multi-Ping"),
        ("checklist", "Port Scanner"),
        ("stopwatch", "HTTP Latency"),
        ("globe", "DNS Lookup"),
        ("magnifyingglass.circle", "WHOIS"),
        ("lock.shield", "SSL/TLS Inspector"),
        ("network", "Network Interfaces"),
        ("wifi", "Wi-Fi Inspector"),
        ("arrow.triangle.branch", "Route Table"),
        ("chart.bar.xaxis", "Bandwidth Monitor"),
    ]

    private func showAck() {
        let alert = NSAlert()
        alert.messageText = "Acknowledgements"
        alert.informativeText = """
        System tools & frameworks used by NetUtil:

        • /sbin/ping — ICMP echo requests
        • /usr/sbin/traceroute — Hop-by-hop path discovery
        • /usr/bin/whois — WHOIS queries
        • /usr/bin/dig — DNS record lookups
        • /usr/sbin/netstat — Routing table

        Apple Frameworks:
        • SwiftUI + Swift Charts — UI and data visualization
        • Network.framework — TCP port scanning
        • CoreWLAN.framework — Wi-Fi inspection
        • MapKit — Traceroute Route Map
        • CoreLocation — Geo coordinate handling
        • CryptoKit — SHA-256 certificate fingerprinting

        Geolocation data provided by ipinfo.io
        (opt-in, can be disabled in Settings → Privacy)
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
