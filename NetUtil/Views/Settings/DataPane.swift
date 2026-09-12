import SwiftUI

/// One place to move NetUtil's data around: a single JSON backup that can
/// be restored here or on another Mac.
struct DataPane: View {
    @Environment(ToolStore.self) private var tools
    @AppStorage("backupIncludeHistory") private var includeHistory = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Save your preferences, enabled tools, favorites, and SSL watchlist to a single file. Restore it on this Mac or another one.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Include history and statistics", isOn: $includeHistory)
                    .accessibilityLabel("Include History and Statistics")

                HStack(spacing: Metrics.spacingMD) {
                    Button("Export…") {
                        if let outcome = SettingsBackupService.exportSettings() {
                            statusMessage = outcome.message
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Export Settings to File")

                    Button("Import…") {
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
                Text("Backup & Restore")
            } footer: {
                Text("History and statistics are excluded by default so the file doesn't reveal which hosts you scanned.")
            }
        }
        .formStyle(.grouped)
    }
}
