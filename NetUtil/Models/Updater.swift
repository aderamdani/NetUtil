import Foundation
import AppKit
import Combine

@MainActor
class Updater: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var updateReady = false
    @Published var error: String?

    private var downloadTask: URLSessionDownloadTask?
    private var latestVersionURL: URL?
    private var downloadedFileURL: URL?

    func downloadAndInstall(from url: URL) {
        self.latestVersionURL = url
        self.isDownloading = true
        self.error = nil
        self.downloadProgress = 0

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
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
            }
        } catch {
            Task { @MainActor in
                self.isDownloading = false
                self.error = "Failed to prepare update file."
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.isDownloading = false
                self.error = error.localizedDescription
            }
        }
    }

    func installAndRelaunch() {
        guard let dmgURL = downloadedFileURL else { return }

        // Clear quarantine flag so macOS doesn't block the mounted DMG
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-dr", "com.apple.quarantine", dmgURL.path]
        try? xattr.run()
        xattr.waitUntilExit()

        NSWorkspace.shared.open(dmgURL)

        let alert = NSAlert()
        alert.messageText = "Update Ready to Install"
        alert.informativeText = "The update DMG has been opened. Drag NetUtil to your Applications folder to replace the current version, then relaunch the app."
        alert.addButton(withTitle: "Quit & Finish Manually")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }
}
