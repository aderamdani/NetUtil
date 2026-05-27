import SwiftUI
import Combine

struct WhoisView: View {
    @ObservedObject var vm: WhoisViewModel
    @StateObject private var history = HostHistory.shared
    @State private var query = ""
    @State private var filterText = ""
    @State private var showLearningGuide = false

    private var displayedLines: [WhoisLine] {
        guard !filterText.isEmpty else { return vm.lines }
        let q = filterText.lowercased()
        return vm.lines.filter { $0.raw.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. STANDARD HEADER (Fixed Top)
            controlBar
                .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let err = vm.error {
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                            Text(err)
                        }
                        .foregroundColor(.red)
                        .font(.system(size: 13, weight: .bold))
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    if !vm.lines.isEmpty {
                        // 2. INTERPRETATION HEADER
                        interpretationHeader
                        
                        // 3. STATS BAR
                        statsBar
                        
                        // 4. WHOIS OUTPUT
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("WHOIS RECORD DATA", systemImage: "text.justify.left")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.secondary)
                                    .kerning(1)
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .foregroundColor(.secondary)
                                    TextField("Filter results...", text: $filterText)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 11, weight: .bold))
                                        .frame(width: 150)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(6)
                            }
                            
                            outputView
                                .background(Color(.controlBackgroundColor).opacity(0.5))
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
                        }
                    } else if !vm.isRunning {
                        emptyState
                    }
                    
                    if vm.isRunning {
                        HStack(spacing: 12) {
                            ProgressView().controlSize(.small)
                            Text("Querying public WHOIS databases...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) {
            whoisLearningGuideSheet
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // 1. Target Input with History
            TextField("Domain or IP address", text: $query)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(width: 250)
                .help("Target to lookup.")
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

            // 3. Action Group
            if !vm.lines.isEmpty {
                Menu {
                    Button("Export as Text") {
                        Exporter.save(string: vm.lines.map(\.raw).joined(separator: "\n"),
                                      defaultName: "whois-\(query).txt", ext: "txt")
                    }
                } label: {
                    Label("Report", systemImage: "doc.text.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(action: lookup) {
                HStack(spacing: 6) {
                    if vm.isRunning {
                        Image(systemName: "stop.fill").font(.system(size: 11, weight: .bold))
                        Text("Stop")
                    } else {
                        Image(systemName: "play.fill")
                        Text("Lookup")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && query.isEmpty)
            
            Button { showLearningGuide = true } label: {
                Image(systemName: "book.fill").font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("WHOIS Learning Guide")
        }
    }
    
    private var interpretationHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            let hasData = !vm.lines.isEmpty
            Image(systemName: hasData ? "person.text.rectangle.fill" : "questionmark.circle.fill")
                .font(.title2)
                .foregroundColor(hasData ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(hasData ? "Owner Data Retrieved" : "No Data")
                    .font(.headline)
                Text(hasData ? "Domain registration and administrative contact information found." : "Waiting for query...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "TOTAL LINES", value: "\(vm.lines.count)", icon: "text.alignleft")
            if let registry = vm.lines.first(where: { $0.label?.lowercased().contains("registry") == true })?.value {
                StatCard(title: "REGISTRY", value: registry, icon: "building.2.fill", color: .blue)
            }
            StatCard(title: "FILTERED", value: "\(displayedLines.count)", icon: "line.3.horizontal.decrease")
            Spacer()
        }
    }

    private var outputView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(displayedLines) { line in
                    HStack(spacing: 0) {
                        if let label = line.label {
                            Text(label + ":")
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
            .padding(.vertical, 12)
        }
        .frame(minHeight: 400)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "magnifyingglass.circle").font(.system(size: 32)).foregroundColor(.accentColor)
            }
            Text("Ready to query registration data. Enter a domain and press Lookup.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.top, 40)
    }

    private func lookup() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        history.record(q)
        vm.lookup(q)
    }
    
    private var whoisLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WHOIS Learning Guide").font(.title2.bold())
                    Text("Learn how to audit domain ownership and records.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "What is WHOIS?", icon: "person.text.rectangle") {
                        Text("WHOIS is a database that contains information about the registered users or assignees of an Internet resource, such as a domain name or an IP address block.")
                    }
                    GuideSection(title: "Data Privacy", icon: "lock.shield") {
                        Text("Many domain owners use privacy protection services to hide their personal details. In such cases, you will see the info of the privacy provider instead.")
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct WhoisLine: Identifiable {
    let id = UUID()
    let raw: String
    var label: String? {
        guard raw.contains(":"), !raw.hasPrefix("%"), !raw.hasPrefix("#"),
              !raw.hasPrefix(">>>") else { return nil }
        return raw.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces)
    }
    var value: String? {
        guard label != nil else { return nil }
        return raw.components(separatedBy: ":").dropFirst()
            .joined(separator: ":").trimmingCharacters(in: .whitespaces)
    }
}

@MainActor
class WhoisViewModel: ObservableObject {
    @Published var lines: [WhoisLine] = []
    @Published var isRunning = false
    @Published var error: String?

    private var process: Process?

    deinit { process?.terminate() }

    func lookup(_ query: String) {
        cancel()
        lines = []
        error = nil
        isRunning = true

        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/whois")
        p.arguments = [query]
        p.standardOutput = pipe
        p.standardError = Pipe()

        p.terminationHandler = { [weak self] _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            let parsed = text.components(separatedBy: "\n").map { WhoisLine(raw: $0) }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lines = parsed
                self.isRunning = false
            }
        }

        process = p
        do { try p.run() } catch {
            self.error = error.localizedDescription
            isRunning = false
        }
    }

    func cancel() {
        process?.terminate()
        process = nil
        isRunning = false
    }
}
