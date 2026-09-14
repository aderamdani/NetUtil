import SwiftUI
import Observation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, tools, privacy, data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .tools:   "Tools"
        case .privacy: "Privacy"
        case .data:    "Data"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .tools:   "wrench.and.screwdriver"
        case .privacy: "hand.raised"
        case .data:    "externaldrive"
        }
    }
}

struct SettingsEntry: Identifiable {
    let id = UUID()
    let tab: SettingsTab
    let title: String
    let keywords: [String]
}

enum SettingsCatalog {
    static let entries: [SettingsEntry] = [
        .init(tab: .general, title: "Keep NetUtil available after closing the window", keywords: ["background", "menu bar", "close", "quit", "dock"]),
        .init(tab: .general, title: "Show live speed in the menu bar icon", keywords: ["menu bar", "traffic", "throughput"]),
        .init(tab: .general, title: "Notify me about connection problems", keywords: ["alerts", "notification", "ping", "loss"]),
        .init(tab: .general, title: "Play a sound when a ping is lost", keywords: ["beep", "sound", "loss"]),
        .init(tab: .general, title: "Pings per run", keywords: ["ping", "count", "packets", "default"]),
        .init(tab: .general, title: "Time between pings", keywords: ["ping", "interval", "delay"]),
        .init(tab: .general, title: "Stop after repeated timeouts", keywords: ["auto", "stop", "timeout", "loss"]),
        .init(tab: .general, title: "Traceroute max hops", keywords: ["traceroute", "hops", "ttl"]),
        .init(tab: .general, title: "Traceroute re-trace interval", keywords: ["traceroute", "interval", "continuous"]),
        .init(tab: .general, title: "Log lines kept per tool", keywords: ["log", "buffer", "raw", "output", "memory"]),
        .init(tab: .general, title: "Latency Colors", keywords: ["rtt", "threshold", "color", "green", "red"]),
        .init(tab: .general, title: "Packet loss alert", keywords: ["loss", "threshold", "alert"]),

        .init(tab: .tools, title: "Enable or disable tools", keywords: ["tools", "availability", "sidebar", "hide", "show"]),
        .init(tab: .tools, title: "Port scan timeout", keywords: ["port scanner", "timeout"]),
        .init(tab: .tools, title: "Port scan threads", keywords: ["port scanner", "concurrency", "threads"]),
        .init(tab: .tools, title: "HTTP request timeout", keywords: ["http", "latency", "timeout"]),
        .init(tab: .tools, title: "SSL handshake timeout", keywords: ["ssl", "tls", "timeout"]),
        .init(tab: .tools, title: "Speed refresh interval", keywords: ["bandwidth", "refresh", "interval"]),

        .init(tab: .privacy, title: "Look up hop locations in Traceroute", keywords: ["geolocation", "ipinfo", "privacy", "map"]),
        .init(tab: .privacy, title: "Saved hosts", keywords: ["history", "clear", "hosts"]),
        .init(tab: .privacy, title: "Remote connections", keywords: ["network", "transparency", "hosts"]),
        .init(tab: .privacy, title: "Sandbox entitlement", keywords: ["privacy", "permission", "network"]),

        .init(tab: .data, title: "Export settings", keywords: ["backup", "save", "json"]),
        .init(tab: .data, title: "Import settings", keywords: ["restore", "backup", "json"]),
        .init(tab: .data, title: "Include history and statistics", keywords: ["backup", "history", "privacy"])
    ]
}

struct SettingsView: View {
    @State private var selection: SettingsTab = .general
    @State private var query = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private var matches: [SettingsEntry] {
        let q = trimmedQuery.lowercased()
        guard !q.isEmpty else { return [] }
        return SettingsCatalog.entries.filter { entry in
            entry.title.lowercased().contains(q) ||
            entry.keywords.contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if trimmedQuery.isEmpty {
                tabs
            } else {
                results
            }
        }
        .frame(width: 520, height: 460)
    }

    private var searchBar: some View {
        HStack(spacing: Metrics.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption2.weight(.bold))
            TextField("Search settings", text: $query)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .accessibilityLabel("Search settings")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(Metrics.spacingMD)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusSM))
        .padding(.horizontal, Metrics.spacingLG)
        .padding(.vertical, Metrics.spacingMD)

        .overlay(Divider(), alignment: .bottom)
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            GeneralPane()
                .tag(SettingsTab.general)
                .tabItem { Label(SettingsTab.general.title, systemImage: SettingsTab.general.icon) }
            ToolsPane()
                .tag(SettingsTab.tools)
                .tabItem { Label(SettingsTab.tools.title, systemImage: SettingsTab.tools.icon) }
            PrivacyPane()
                .tag(SettingsTab.privacy)
                .tabItem { Label(SettingsTab.privacy.title, systemImage: SettingsTab.privacy.icon) }
            DataPane()
                .tag(SettingsTab.data)
                .tabItem { Label(SettingsTab.data.title, systemImage: SettingsTab.data.icon) }
        }
    }

    private var results: some View {
        Group {
            if matches.isEmpty {
                VStack(spacing: Metrics.spacingSM) {
                    Text("No matching settings")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try a different word — e.g. \"DNS\", \"backup\", \"threshold\".")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(matches) { entry in
                    Button {
                        selection = entry.tab
                        query = ""
                    } label: {
                        HStack(spacing: Metrics.spacingMD) {
                            Image(systemName: entry.tab.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 20)
                            Text(entry.title)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(entry.tab.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(entry.title), in \(entry.tab.title)")
                }
                .listStyle(.inset)
            }
        }
    }
}
