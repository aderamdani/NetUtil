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
        
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent("relaunch.sh")
        let appPath = Bundle.main.bundlePath
        let appName = Bundle.main.bundleURL.lastPathComponent
        
        let script = """
        #!/bin/bash
        # Wait for the app to quit
        sleep 2
        
        # Mount DMG
        MOUNT_POINT=$(hdiutil mount "\(dmgURL.path)" | tail -n1 | cut -f3-)
        
        if [ -d "$MOUNT_POINT" ]; then
            # Replace app
            rm -rf "\(appPath)"
            cp -R "$MOUNT_POINT/\(appName)" "\(appPath)"
            
            # Cleanup
            hdiutil detach "$MOUNT_POINT"
            rm "\(dmgURL.path)"
            
            # Restart app
            open "\(appPath)"
        fi
        
        # Self delete
        rm -- "$0"
        """
        
        do {
            try script.write(to: scriptPath, atomically: true, encoding: .utf8)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath.path]
            try process.run()
            
            NSApp.terminate(nil)
        } catch {
            self.error = "Failed to launch updater script."
        }
    }
}
