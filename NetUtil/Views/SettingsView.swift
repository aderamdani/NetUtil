import SwiftUI
import Observation

// MARK: - Root

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralPane()
                .tabItem { Label("General", systemImage: "gearshape") }
            ThresholdsPane()
                .tabItem { Label("Thresholds", systemImage: "dial.medium") }
            ToolsPane()
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
            PrivacyPane()
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
            BackupPane()
                .tabItem { Label("Backup", systemImage: "externaldrive") }
        }
        .frame(width: 480, height: 420)
    }
}
