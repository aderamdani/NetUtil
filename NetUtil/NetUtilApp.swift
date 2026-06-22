import SwiftUI
import AppKit
import Observation

@main
struct NetUtilApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var tools = ToolStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(tools)
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
                .environment(tools)
                .environment(tools.interfaces)
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
            NSApp.setActivationPolicy(.accessory)
            postPolicyChange()
            return false
        }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: "backgroundOnClose") &&
           NSApp.windows.allSatisfy({ !$0.isVisible }) {
            NSApp.setActivationPolicy(.accessory)
            postPolicyChange()
        }
    }

    private func postPolicyChange() {
        NotificationCenter.default.post(name: .init("netutil.activationPolicyChanged"), object: nil)
    }
}

extension NSApplication {
    static func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NotificationCenter.default.post(name: .init("netutil.activationPolicyChanged"), object: nil)
        NSApp.activate()
        if let win = NSApp.windows.first(where: { $0.canBecomeMain }) {
            win.makeKeyAndOrderFront(nil)
        }
    }
}
