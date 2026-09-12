import SwiftUI
import AppKit

/// Bridges the menu bar to `ContentView`'s local `selection` without moving
/// that state into the store. `ContentView` publishes the closure via
/// `.focusedSceneValue`; the Tools menu consumes it.
struct ToolSelectionKey: FocusedValueKey {
    typealias Value = (Tool) -> Void
}

extension FocusedValues {
    var selectTool: ((Tool) -> Void)? {
        get { self[ToolSelectionKey.self] }
        set { self[ToolSelectionKey.self] = newValue }
    }
}

/// App-specific menu bar commands: settings import/export, quick copy,
/// global refresh, the menu-bar traffic toggle, and tool navigation.
@MainActor
struct AppCommands: Commands {
    let tools: ToolStore
    @Binding var menuBarShowTraffic: Bool

    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.selectTool) private var selectTool

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandGroup(replacing: .appInfo) {
            Button("About NetUtil") {
                openWindow(id: "about")
            }
            Button("Check for Updates...") {
                Updater.shared.checkForUpdates(interactive: true)
            }
        }

        CommandGroup(after: .importExport) {
            Button("Export Settings…") {
                handle(SettingsBackupService.exportSettings())
            }
            Button("Import Settings…") {
                handle(SettingsBackupService.importSettings(onApplied: {
                    tools.reapplyImportedSettings()
                }))
            }
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Public IP") { copy(tools.externalIP) }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(tools.externalIP == "Checking..." || tools.externalIP == "Unknown")
            Button("Copy Local IP") { copy(tools.primaryLocalIP) }
                .keyboardShortcut("l", modifiers: [.command, .option])
                .disabled(tools.primaryLocalIP == "—")
            Button("Copy Hostname") { copy(Host.current().localizedName ?? "") }
        }

        CommandGroup(after: .sidebar) {
            Button("Refresh Network Status") { tools.refreshGlobalStatus() }
                .keyboardShortcut("r", modifiers: .command)
            Toggle("Show Traffic in Menu Bar", isOn: $menuBarShowTraffic)
        }

        CommandMenu("Tools") {
            ForEach(ToolGroup.allCases, id: \.self) { group in
                let items = tools.catalog.availableTools(in: group)
                if !items.isEmpty {
                    if let title = group.title {
                        Menu(title) {
                            ForEach(items) { tool in toolButton(tool) }
                        }
                    } else {
                        ForEach(items) { tool in toolButton(tool) }
                    }
                }
            }
        }

        CommandGroup(replacing: .help) {
            Button("NetUtil Help") { openWindow(id: "help") }
                .keyboardShortcut("?", modifiers: .command)
        }
    }

    @ViewBuilder
    private func toolButton(_ tool: Tool) -> some View {
        if let key = tool.shortcut, !tool.shortcutModifiers.isEmpty {
            Button(tool.displayName, systemImage: tool.icon) { selectTool?(tool) }
                .keyboardShortcut(key, modifiers: tool.shortcutModifiers)
                .disabled(selectTool == nil)
        } else {
            Button(tool.displayName, systemImage: tool.icon) { selectTool?(tool) }
                .disabled(selectTool == nil)
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func handle(_ outcome: SettingsBackupService.Outcome?) {
        guard let outcome else { return }
        switch outcome {
        case .success(let message):
            Notifier.post(title: "NetUtil Settings", body: message)
        case .failure(let message):
            let alert = NSAlert()
            alert.messageText = "Settings Backup"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
