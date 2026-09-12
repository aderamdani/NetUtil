import SwiftUI
import Observation

// MARK: - Root

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralPane()
                .tabItem { Label("General", systemImage: "gearshape") }
            ToolsPane()
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
            PrivacyPane()
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
            DataPane()
                .tabItem { Label("Data", systemImage: "externaldrive") }
        }
        .frame(width: 520, height: 460)
    }
}
