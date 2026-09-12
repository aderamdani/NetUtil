import SwiftUI

struct BackupPane: View {
    @Environment(ToolStore.self) private var tools
    @AppStorage("backupIncludeHistory") private var includeHistory = false
    @State private var statusMessage: String?

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
                    Button("Export Settings…") {
                        if let outcome = SettingsBackupService.exportSettings() {
                            statusMessage = outcome.message
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Export Settings to File")
                    Button("Import Settings…") {
                        if let outcome = SettingsBackupService.importSettings(onApplied: {
                            tools.reapplyImportedSettings()
                        }) {
                            statusMessage = outcome.message
                        }
                    }
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
    }
}
