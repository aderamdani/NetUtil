import SwiftUI
import AppKit
import Observation

@main
struct NetUtilApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var tools = ToolStore()
    @AppStorage("menuBarShowTraffic") private var menuBarShowTraffic = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(tools)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands(tools: tools, menuBarShowTraffic: $menuBarShowTraffic)
        }

        Window("About NetUtil", id: "about") {
            AboutView()
                .frame(width: 560, height: 620)
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
                .environment(tools)
        }

        MenuBarExtra {
            MenuBarView()
                .environment(tools)
                .environment(tools.interfaces)
        } label: {
            MenuBarLabel()
                .environment(tools)
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

    /// Hides the main window and drops to an accessory (menu-bar only) app.
    static func enterMenuBarOnly() {
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.post(name: .init("netutil.activationPolicyChanged"), object: nil)
        for window in NSApp.windows where window.canBecomeMain {
            window.orderOut(nil)
        }
    }
}
