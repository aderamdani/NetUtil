import SwiftUI
import Observation

struct WhoisView: View {
    var vm: WhoisViewModel
    @Environment(ToolStore.self) private var tools
    @State private var history = HostHistory.shared
    @State private var query = ""
    @State private var filterText = ""
    @State private var showLearningGuide = false

    private var displayedLines: [WhoisLine] {
        guard !filterText.isEmpty else { return vm.lines }
        let q = filterText.lowercased()
        return vm.lines.filter { $0.raw.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            whoisMoodBar

            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        ErrorBanner(message: err)
                    }
                    
                    if !vm.lines.isEmpty {
                        interpretationSection
                        
                        statsBarSection
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                sectionHeader("Registry Dataset", systemImage: "text.justify.left")
                                Spacer()
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .foregroundColor(.secondary)
                                    TextField("Filter results...", text: $filterText)
                                        .textFieldStyle(.plain)
                                        .font(.subheadline)
                                        .frame(width: 180)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
                            }
                            
                            outputView
                        }
                    } else if vm.isRunning {
                        loadingState
                    } else {
                        emptyState
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "WHOIS") }
    }

    private var whoisMoodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            if vm.isRunning {
                return ("hourglass", .secondary, "Querying registry for \(vm.lastQuery)...")
            }
            guard !vm.lines.isEmpty else {
                return ("magnifyingglass.circle", .secondary, "Enter a domain or IP to query registration data")
            }
            let fields = vm.lines.filter { $0.label != nil }.count
            if fields == 0 {
                return ("questionmark.circle.fill", .orange, "No structured fields parsed for \(vm.lastQuery)")
            }
            return ("checkmark.circle.fill", .green, "\(fields) field\(fields == 1 ? "" : "s") parsed  —  \(vm.lastQuery)")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    // MARK: - Components

    private var controlBar: some View {
        ToolControlBar(icon: "magnifyingglass.circle.fill", title: "WHOIS",
                       host: $query, placeholder: "Domain or IP address",
                       textFieldAccessibilityLabel: "Query Input",
                       accessibilityToolName: "WHOIS Lookup Tool",
                       history: history, onSubmit: lookup) {
            HStack(spacing: 12) {
                if !vm.lines.isEmpty {
                    ReportMenuButton(
                        onExportPDF: { Exporter.saveWhoisPDF(lines: vm.lines, query: query) },
                        onExportCSV: {
                            let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                            Exporter.save(string: vm.lines.map(\.raw).joined(separator: "\n"),
                                          defaultName: "NetUtil-Whois-\(query)-\(ts.string(from: Date())).csv",
                                          ext: "csv")
                        },
                        onCopySummary: {
                            let fields = vm.lines.filter { $0.label != nil }
                            let summary = "Query: \(query)\nParsed fields: \(fields.count)\nFirst: \(fields.prefix(1).compactMap(\.value).first ?? "—")"
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(summary, forType: .string)
                        }
                    )
                }

                Button(action: { vm.isRunning ? vm.stop() : lookup() }) {
                    Label(vm.isRunning ? "Stop" : "Lookup", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.glassProminent)
                .tint(vm.isRunning ? .red : .accentColor)
                .disabled(!vm.isRunning && query.isEmpty)
                .accessibilityLabel(vm.isRunning ? "Stop Lookup" : "Start Lookup")

                if !query.isEmpty {
                    let isFav = tools.favorites.isFavorite(query)
                    Button { tools.favorites.toggle(host: query) } label: {
                        Image(systemName: isFav ? "star.fill" : "star").foregroundColor(isFav ? .orange : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(isFav ? "Remove from Favorites" : "Add to Favorites")
                }

                Button { showLearningGuide = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Show Help Guide")
            }
        }
    }
    
    private var interpretationSection: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "person.text.rectangle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Registry Record Identified")
                    .font(.headline)
                Text("Ownership and administrative metadata successfully retrieved.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Registry Record Identified.")
            
            Spacer()
        }
    }

    private var statsBarSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Record Lines", value: "\(vm.lines.count)", icon: "text.alignleft")
            
            if let registrar = findValue(for: "Registrar") {
                StatCard(title: "Registrar", value: registrar, icon: "building.2.fill", color: .blue)
            }
            
            if let expires = findValue(for: "Expiry") ?? findValue(for: "Expiration") {
                StatCard(title: "Expiration", value: parseDate(expires), icon: "calendar.badge.clock", color: .orange)
            }
        }
    }

    private var outputView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(displayedLines) { line in
                    HStack(alignment: .top, spacing: 0) {
                        if let label = line.label {
                            Text(label)
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundColor(.accentColor)
                                .frame(width: 180, alignment: .leading)
                            
                            Text(line.value ?? "")
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundColor(.primary)
                        } else {
                            Text(line.raw)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(line.raw.hasPrefix("%") || line.raw.hasPrefix("#") ? .secondary : .primary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 1)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(line.label.map { "\($0): \(line.value ?? "")" } ?? line.raw)
                }
            }
            .padding(.vertical, 16)
        }
        .frame(minHeight: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).foregroundColor(.accentColor).font(.system(.caption2, design: .default).weight(.bold))
            Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var emptyState: some View {
        ToolStateView.empty(title: "No Query Executed",
                            subtitle: "Enter a domain or IP to query its registration database.")
    }

    private var loadingState: some View {
        ToolStateView.loading(message: "Querying WHOIS Database...")
    }

    private func lookup() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }; history.record(q); vm.start(q)
    }
    
    // MARK: - Helpers
    
    private func findValue(for keyword: String) -> String? {
        vm.lines.first(where: { $0.label?.lowercased().contains(keyword.lowercased()) == true })?.value
    }
    
    private func parseDate(_ raw: String) -> String {
        // Simple heuristic for date extraction (YYYY-MM-DD)
        let pattern = #"\d{4}-\d{2}-\d{2}"#
        if let range = raw.range(of: pattern, options: .regularExpression) {
            return String(raw[range])
        }
        return raw.components(separatedBy: " ").first ?? raw
    }
}

struct WhoisLine: Identifiable {
    let id = UUID()
    let raw: String
    var label: String?
    var value: String?
}

