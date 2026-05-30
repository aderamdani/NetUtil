import SwiftUI
import Combine
import Observation

struct WhoisView: View {
    var vm: WhoisViewModel
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
            
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
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

    // MARK: - Components

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("WHOIS")
                        .font(.headline)
                }
                
                Divider().frame(height: 16).padding(.horizontal, 4)
                
                TextField("Domain or IP address", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 250)
                    .onSubmit(lookup)
                    .overlay(alignment: .trailing) {
                        if !history.hosts.isEmpty {
                            Menu {
                                ForEach(history.hosts, id: \.self) { h in
                                    Button(h) { query = h; lookup() }
                                }
                                Divider()
                                Button("Clear History", role: .destructive) { history.clear() }
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 28)
                            .padding(.trailing, 4)
                        }
                    }

                Spacer()
                
                HStack(spacing: 12) {
                    if !vm.lines.isEmpty {
                        Button { Exporter.save(string: vm.lines.map(\.raw).joined(separator: "\n"), defaultName: "whois-\(query).txt", ext: "txt") } label: {
                            Label("Report", systemImage: "doc.text.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: lookup) {
                        Label(vm.isRunning ? "Stop" : "Lookup", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isRunning ? .red : .accentColor)
                    .disabled(!vm.isRunning && query.isEmpty)
                    
                    Button { showLearningGuide = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            Divider()
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
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.accentColor)
                                .frame(width: 180, alignment: .leading)
                            
                            Text(line.value ?? "")
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundColor(.primary)
                        } else {
                            Text(line.raw)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(line.raw.hasPrefix("%") || line.raw.hasPrefix("#") ? .secondary : .primary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 1)
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
    }
    
    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(msg)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 0.5))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No Query Executed")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Enter a domain or IP to query its registration database.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Querying WHOIS Database...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    private func lookup() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }; history.record(q); vm.lookup(q)
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

@Observable
@MainActor
class WhoisViewModel {
    var lines: [WhoisLine] = []
    var isRunning = false
    var error: String?
    private var process: Process?

    func lookup(_ query: String) {
        isRunning = true; error = nil; lines = []
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/whois"); p.arguments = [query]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        p.terminationHandler = { _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                var parsed: [WhoisLine] = []
                for l in output.components(separatedBy: "\n") {
                    if l.contains(": "), let idx = l.firstIndex(of: ":") {
                        let key = String(l[..<idx]).trimmingCharacters(in: .whitespaces)
                        let val = String(l[l.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                        if key.count < 30 { parsed.append(WhoisLine(raw: l, label: key, value: val)); continue }
                    }
                    parsed.append(WhoisLine(raw: l))
                }
                self.lines = parsed; self.isRunning = false
            }
        }
        process = p
        do { try p.run() } catch { self.error = error.localizedDescription; isRunning = false }
    }
    
    func cancel() { process?.terminate(); process = nil; isRunning = false }
}

