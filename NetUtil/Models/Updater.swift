import Foundation
import AppKit
import SwiftUI
import Combine
import Observation

@MainActor
@Observable
final class Updater: NSObject, URLSessionDownloadDelegate {
    static let shared = Updater()

    var downloadProgress: Double = 0
    var isDownloading = false
    var updateReady = false
    var error: String?
    var isChecking = false

    private var downloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession?
    private var downloadedFileURL: URL?
    private var progressPanel: NSPanel?

    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.7.0"

    private override init() { super.init() }

    // MARK: - Check

    func checkForUpdates(interactive: Bool = true) {
        guard !isChecking && !isDownloading else { return }
        isChecking = true
        error = nil

        guard let url = URL(string: "https://api.github.com/repos/aderamdani/NetUtil/releases/latest") else {
            isChecking = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, networkError in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isChecking = false

                if let networkError {
                    guard interactive else { return }
                    self.showAlert(title: "Update Check Failed",
                                   message: networkError.localizedDescription)
                    return
                }

                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    if interactive {
                        self.showAlert(title: "Update Check Failed",
                                       message: "Could not parse release information from GitHub.")
                    }
                    return
                }

                let latestVersion = tagName.replacingOccurrences(of: "v", with: "")
                guard latestVersion.compare(self.currentVersion, options: .numeric) == .orderedDescending else {
                    if interactive {
                        self.showAlert(title: "Up to Date",
                                       message: "You are running the latest version of NetUtil (v\(self.currentVersion)).")
                    }
                    return
                }

                guard let assets = json["assets"] as? [[String: Any]],
                      let dmg = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
                      let urlString = dmg["browser_download_url"] as? String,
                      let dlURL = URL(string: urlString) else {
                    if interactive {
                        self.showAlert(title: "Update Available",
                                       message: "NetUtil v\(latestVersion) is available but no installer was found in the release.")
                    }
                    return
                }

                if interactive {
                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "NetUtil v\(latestVersion) is available. Download now?"
                    alert.addButton(withTitle: "Download Update")
                    alert.addButton(withTitle: "Later")
                    NSApp.activate()
                    if alert.runModal() == .alertFirstButtonReturn {
                        self.downloadAndInstall(from: dlURL)
                    }
                }
            }
        }.resume()
    }

    // MARK: - Download

    func downloadAndInstall(from url: URL) {
        guard !isDownloading else { return }
        isDownloading = true
        error = nil
        downloadProgress = 0
        updateReady = false

        closeProgressPanel()
        showProgressPanel()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 300
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        downloadSession = session
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                 didWriteData bytesWritten: Int64,
                                 totalBytesWritten: Int64,
                                 totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in self.downloadProgress = progress }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                 didFinishDownloadingTo location: URL) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("NetUtilUpdate.dmg")
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.moveItem(at: location, to: tempURL)
            Task { @MainActor in
                self.downloadedFileURL = tempURL
                self.isDownloading = false
                self.downloadProgress = 1.0
                self.updateReady = true
                self.closeProgressPanel()
                self.installAndRelaunch()
            }
        } catch {
            Task { @MainActor in
                self.isDownloading = false
                self.closeProgressPanel()
                self.showAlert(title: "Download Failed", message: "Could not save the update file: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                                 didCompleteWithError error: Error?) {
        guard let error else { return }
        Task { @MainActor in
            self.isDownloading = false
            self.closeProgressPanel()
            self.showAlert(title: "Download Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Install

    func installAndRelaunch() {
        guard let dmgURL = downloadedFileURL else { return }

        Task.detached {
            let xattr = Process()
            xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattr.arguments = ["-dr", "com.apple.quarantine", dmgURL.path]
            try? xattr.run()
            xattr.waitUntilExit()

            await MainActor.run {
                NSApp.activate()
                NSWorkspace.shared.open(dmgURL)

                let alert = NSAlert()
                alert.messageText = "Update Ready"
                alert.informativeText = "The installer has been opened. Drag NetUtil to your Applications folder to complete the update, then relaunch."
                alert.addButton(withTitle: "Quit & Install")
                alert.addButton(withTitle: "Later")
                if alert.runModal() == .alertFirstButtonReturn {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    // MARK: - Panel Helpers

    private func showProgressPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 100),
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.title = "Downloading Update"
        panel.center()
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.contentView = NSHostingView(rootView: DownloadProgressView(updater: self))
        progressPanel = panel
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    private func closeProgressPanel() {
        progressPanel?.close()
        progressPanel = nil
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

// MARK: - Progress View

struct DownloadProgressView: View {
    var updater: Updater

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView(value: updater.downloadProgress)
                .progressViewStyle(.linear)
                .tint(.accentColor)

            HStack {
                Text(String(format: "%.0f%%", updater.downloadProgress * 100))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("Downloading installer...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
