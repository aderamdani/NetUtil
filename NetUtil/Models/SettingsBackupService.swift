import AppKit
import UniformTypeIdentifiers

/// UI shell around `SettingsBackup`: drives the save/open panels and the
/// replace-confirmation alert so the same flow can run from the File menu
/// or Settings > Backup. The model layer stays panel-free and unit-testable.
@MainActor
enum SettingsBackupService {
    enum Outcome {
        case success(String)
        case failure(String)

        var message: String {
            switch self {
            case .success(let message), .failure(let message): return message
            }
        }
    }

    private static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private static var includeHistory: Bool {
        UserDefaults.standard.bool(forKey: "backupIncludeHistory")
    }

    /// Returns `nil` when the user cancels the save panel.
    static func exportSettings() -> Outcome? {
        let backup = SettingsBackup.collect(from: .standard, includeHistory: includeHistory, appVersion: appVersion)
        guard let data = try? backup.encoded() else {
            return .failure("Could not encode settings.")
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "NetUtil-Settings-\(fileTimestamp.string(from: Date())).json"
        if let contentType = UTType(filenameExtension: "json") {
            panel.allowedContentTypes = [contentType]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try data.write(to: url)
            return .success("Exported \(backup.values.count) settings.")
        } catch {
            return .failure("Export failed: \(error.localizedDescription)")
        }
    }

    /// Returns `nil` when the user cancels a panel or the confirmation.
    static func importSettings(onApplied: () -> Void) -> Outcome? {
        let panel = NSOpenPanel()
        if let contentType = UTType(filenameExtension: "json") {
            panel.allowedContentTypes = [contentType]
        }
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let data = try? Data(contentsOf: url) else {
            return .failure("Could not read backup: invalid settings file.")
        }
        do {
            let backup = try SettingsBackup.decode(from: data)
            guard confirmReplace() else { return nil }
            let written = SettingsBackup.apply(backup, to: .standard)
            onApplied()
            return .success("Imported \(written.count) settings. No restart needed.")
        } catch let error as BackupError {
            switch error {
            case .unsupportedSchema(let version):
                return .failure("Unsupported backup (schema v\(version)). Export a fresh backup from this version of NetUtil.")
            }
        } catch {
            return .failure("Could not read backup: invalid settings file.")
        }
    }

    private static func confirmReplace() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Replace Settings?"
        alert.informativeText = "Importing overwrites preferences, enabled tools, favorites, and the SSL watchlist on this Mac. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace Settings")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
