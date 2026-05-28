import SwiftUI
import AppKit

@main
struct NetUtilApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var tools = ToolStore()
    @StateObject private var menuBarVM = MenuBarViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tools)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    Updater.shared.checkForUpdates(interactive: true)
                }
            }
            CommandGroup(replacing: .help) {
                Button("NetUtil Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        Window("About NetUtil", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)

        Window("NetUtil Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(tools)
                .environmentObject(tools.interfaces)
                .environmentObject(menuBarVM)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let keepRunning = UserDefaults.standard.bool(forKey: "backgroundOnClose")
        if keepRunning {
            // Switch to accessory mode — hides Dock icon, keeps menu bar alive.
            NSApp.setActivationPolicy(.accessory)
            return false
        }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Honor the saved policy on launch in case the user previously closed
        // the window and quit with the menu bar still active.
        if UserDefaults.standard.bool(forKey: "backgroundOnClose") &&
           NSApp.windows.allSatisfy({ !$0.isVisible }) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

extension NSApplication {
    /// Restores the Dock icon and brings the main window forward.
    static func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        if let win = NSApp.windows.first(where: { $0.canBecomeMain }) {
            win.makeKeyAndOrderFront(nil)
        }
    }
}
