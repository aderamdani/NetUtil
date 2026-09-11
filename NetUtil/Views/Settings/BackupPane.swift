import SwiftUI
import UniformTypeIdentifiers

struct BackupPane: View {
    @Environment(ToolStore.self) private var tools
    @AppStorage("backupIncludeHistory") private var includeHistory = false
    @State private var statusMessage: String?
    @State private var pendingBackup: SettingsBackup?
    @State private var showImportConfirm = false

    private static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    var body: some View {
        Form {
            Section {
                Text("Save preferences, enabled tools, favorites, and the SSL watchlist to a single JSON file, then restore it on this Mac or another one. No account, no cloud — the file is yours.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Include history & statistics", isOn: $includeHistory)
                    .help("Also backs up session history, daily traffic totals, and saved hosts. These reveal which hosts you scanned — leave off when sharing the file.")
                    .accessibilityLabel("Include History and Statistics")
                HStack(spacing: Metrics.spacingMD) {
                    Button("Export Settings…") { exportSettings() }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Export Settings to File")
                    Button("Import Settings…") { importSettings() }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Import Settings from File")
                    Spacer()
                }
                .padding(.top, Metrics.spacingXS)
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Backup status: \(statusMessage)")
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("History and statistics are excluded by default for privacy.")
            }
        }
        .formStyle(.grouped)
        .alert("Replace Settings?", isPresented: $showImportConfirm) {
            Button("Cancel", role: .cancel) { pendingBackup = nil }
            Button("Replace Settings", role: .destructive) { applyPendingBackup() }
        } message: {
            Text("Importing overwrites preferences, enabled tools, favorites, and the SSL watchlist on this Mac. This cannot be undone.")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private func exportSettings() {
        Task {
            let backup = SettingsBackup.collect(from: .standard, includeHistory: includeHistory, appVersion: appVersion)
            guard let data = try? backup.encoded() else {
                statusMessage = "Could not encode settings."
                return
            }
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "NetUtil-Settings-\(Self.fileTimestamp.string(from: Date())).json"
            if let contentType = UTType(filenameExtension: "json") {
                panel.allowedContentTypes = [contentType]
            }
            let url: URL? = await withCheckedContinuation { continuation in
                panel.begin { response in
                    continuation.resume(returning: response == .OK ? panel.url : nil)
                }
            }
            guard let url else { return }
            do {
                try data.write(to: url)
                statusMessage = "Exported \(backup.values.count) settings."
            } catch {
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func importSettings() {
        Task {
            let panel = NSOpenPanel()
            if let contentType = UTType(filenameExtension: "json") {
                panel.allowedContentTypes = [contentType]
            }
            panel.allowsMultipleSelection = false
            let url: URL? = await withCheckedContinuation { continuation in
                panel.begin { response in
                    continuation.resume(returning: response == .OK ? panel.url : nil)
                }
            }
            guard let url, let data = try? Data(contentsOf: url) else { return }
            do {
                pendingBackup = try SettingsBackup.decode(from: data)
                showImportConfirm = true
            } catch let error as BackupError {
                switch error {
                case .unsupportedSchema(let version):
                    statusMessage = "Unsupported backup (schema v\(version)). Export a fresh backup from this version of NetUtil."
                }
            } catch {
                statusMessage = "Could not read backup: invalid settings file."
            }
        }
    }

    private func applyPendingBackup() {
        guard let backup = pendingBackup else { return }
        let written = SettingsBackup.apply(backup, to: .standard)
        pendingBackup = nil
        tools.reapplyImportedSettings()
        statusMessage = "Imported \(written.count) settings. No restart needed."
    }
}
