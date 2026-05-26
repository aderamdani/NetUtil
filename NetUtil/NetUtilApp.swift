import SwiftUI

@main
struct NetUtilApp: App {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var tools = ToolStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tools)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About NetUtil") {
                    openWindow(id: "about")
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
        } label: {
            Image(systemName: "network")
        }
        .menuBarExtraStyle(.window)
    }
}
