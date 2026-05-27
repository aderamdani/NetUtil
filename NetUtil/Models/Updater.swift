import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
class Updater: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = Updater()
    
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var updateReady = false
    @Published var error: String?
    @Published var isChecking = false

    private var downloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession?
    private var downloadedFileURL: URL?
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.4.1"
    
    private var progressPanel: NSPanel?

    private override init() {
        super.init()
    }

    func checkForUpdates(interactive: Bool = true) {
        guard !isChecking else { return }
        isChecking = true
        
        let url = URL(string: "https://api.github.com/repos/aderamdani/NetUtil/releases/latest")!
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self else { return }
            
            let finishCheck = { (success: Bool, message: String?, latestVer: String?, dlURL: URL?) in
                Task { @MainActor in
                    self.isChecking = false
                    if interactive {
                        if !success {
                            let alert = NSAlert()
                            alert.messageText = "Update Check Failed"
                            alert.informativeText = message ?? "Could not reach the update server."
                            alert.runModal()
                        } else if let latest = latestVer, let url = dlURL {
                            let alert = NSAlert()
                            alert.messageText = "Update Available"
                            alert.informativeText = "NetUtil v\(latest) is ready. Upgrade now?"
                            alert.addButton(withTitle: "Download Update")
                            alert.addButton(withTitle: "Later")
                            if alert.runModal() == .alertFirstButtonReturn {
                                self.downloadAndInstall(from: url)
                            }
                        } else {
                            let alert = NSAlert()
                            alert.messageText = "Up to Date"
                            alert.informativeText = "You are running the latest version of NetUtil (v\(self.currentVersion))."
                            alert.runModal()
                        }
                    }
                }
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let assets = json["assets"] as? [[String: Any]] else {
                finishCheck(false, "Could not fetch release information.", nil, nil)
                return
            }
            
            let latestVersion = tagName.replacingOccurrences(of: "v", with: "")
            if latestVersion.compare(self.currentVersion, options: .numeric) == .orderedDescending {
                if let dmg = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
                   let dlURL = URL(string: dmg["browser_download_url"] as? String ?? "") {
                    finishCheck(true, nil, latestVersion, dlURL)
                } else {
                    finishCheck(false, "No suitable DMG found in the latest release.", nil, nil)
                }
            } else {
                finishCheck(true, nil, nil, nil)
            }
        }.resume()
    }

    func downloadAndInstall(from url: URL) {
        self.isDownloading = true
        self.error = nil
        self.downloadProgress = 0
        self.updateReady = false
        
        showProgressPanel()

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.downloadSession = session
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    private func showProgressPanel() {
        if progressPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                styleMask: [.titled, .nonactivatingPanel],
                backing: .buffered, defer: false)
            panel.title = "Downloading Update"
            panel.center()
            panel.isFloatingPanel = true
            panel.level = .floating
            
            let hostingView = NSHostingView(rootView: DownloadProgressView(updater: self))
            panel.contentView = hostingView
            self.progressPanel = panel
        }
        progressPanel?.makeKeyAndOrderFront(nil)
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.downloadProgress = progress
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("NetUtilUpdate.dmg")

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.moveItem(at: location, to: tempURL)

            Task { @MainActor in
                self.downloadedFileURL = tempURL
                self.isDownloading = false
                self.updateReady = true
                self.progressPanel?.close()
                self.installAndRelaunch()
            }
        } catch {
            Task { @MainActor in
                self.isDownloading = false
                self.error = "Failed to prepare update file."
                self.progressPanel?.close()
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.isDownloading = false
                self.error = error.localizedDescription
                self.progressPanel?.close()
            }
        }
    }

    func installAndRelaunch() {
        guard let dmgURL = downloadedFileURL else { return }

        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-dr", "com.apple.quarantine", dmgURL.path]
        try? xattr.run()
        xattr.waitUntilExit()

        NSWorkspace.shared.open(dmgURL)

        let alert = NSAlert()
        alert.messageText = "Update Downloaded"
        alert.informativeText = "The update DMG has been opened. Drag NetUtil to your Applications folder to finish installation, then relaunch the app."
        alert.addButton(withTitle: "Quit & Install")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }
}

struct DownloadProgressView: View {
    @ObservedObject var updater: Updater
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: updater.downloadProgress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
            
            HStack {
                Text(String(format: "%.0f%%", updater.downloadProgress * 100))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Spacer()
                Text("Downloading installer...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
