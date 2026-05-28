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
                VStack(alignment: .leading, spacing: 32) {
                    if let err = vm.error {
                        errorBanner(err)
                    }
                    
                    if !vm.lines.isEmpty {
                        // 2. INTERPRETATION HEADER
                        interpretationHeader
                        
                        // 3. STATS BAR
                        statsBar
                        
                        // 4. WHOIS OUTPUT
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                sectionHeader("Registration Data", systemImage: "text.justify.left")
                                Spacer()
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease.circle").foregroundColor(.secondary)
                                    TextField("Filter...", text: $filterText).textFieldStyle(.plain).font(.system(size: 12, weight: .medium)).frame(width: 150)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 4).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                            
                            outputView
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    } else if !vm.isRunning {
                        emptyState
                    }
                    
                    if vm.isRunning {
                        loadingState
                    }
                }
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) { whoisLearningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
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
                        } label: { Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary) }
                        .menuStyle(.borderlessButton).frame(width: 28).padding(.trailing, 4)
                    }
                }

            Spacer()

            if !vm.lines.isEmpty {
                Button { Exporter.save(string: vm.lines.map(\.raw).joined(separator: "\n"), defaultName: "whois-\(query).txt", ext: "txt") } label: {
                    Label("Report", systemImage: "doc.text.fill").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }

            Button(action: lookup) {
                HStack(spacing: 6) {
                    Image(systemName: vm.isRunning ? "stop.fill" : "play.fill")
                    Text(vm.isRunning ? "Stop" : "Lookup")
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && query.isEmpty)
            
            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }
            .buttonStyle(.borderless)
        }
    }
    
    private var interpretationHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            let hasData = !vm.lines.isEmpty
            Image(systemName: hasData ? "person.text.rectangle.fill" : "questionmark.circle.fill")
                .font(.title2).foregroundColor(hasData ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(hasData ? "Registry Data Found" : "No Data").font(.headline)
                Text(hasData ? "Owner and registration details retrieved." : "Waiting for query...").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCard(title: "Total Lines", value: "\(vm.lines.count)", icon: "text.alignleft")
            if let registry = vm.lines.first(where: { $0.label?.lowercased().contains("registry") == true })?.value {
                StatCard(title: "Registry", value: registry, icon: "building.2.fill", color: .blue)
            }
            Spacer()
        }
    }

    private var outputView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(displayedLines) { line in
                    HStack(spacing: 0) {
                        if let label = line.label {
                            Text(label + ":").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.accentColor).frame(width: 180, alignment: .leading)
                            Text(line.value ?? "").font(.system(size: 11, design: .monospaced)).textSelection(.enabled).foregroundColor(.primary)
                        } else {
                            Text(line.raw).font(.system(size: 11, design: .monospaced)).foregroundColor(line.raw.hasPrefix("%") || line.raw.hasPrefix("#") ? .secondary : .primary).textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 1)
                }
            }
            .padding(.vertical, 12)
        }
        .frame(minHeight: 400)
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).foregroundColor(.accentColor).font(.headline)
            Text(title).font(.headline)
        }
    }
    
    private func errorBanner(_ msg: String) -> some View {
        HStack { Image(systemName: "exclamationmark.octagon.fill"); Text(msg) }
            .foregroundColor(.red).font(.system(size: 13, weight: .semibold))
            .padding(10).background(Color.red.opacity(0.08)).cornerRadius(8)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No Target Selected").font(.headline).foregroundColor(.secondary)
            Spacer()
        }.frame(maxWidth: .infinity, minHeight: 300)
    }

    private var loadingState: some View {
        HStack(spacing: 12) { ProgressView().controlSize(.small); Text("Querying WHOIS database...").font(.subheadline).foregroundColor(.secondary) }.padding(.top, 8)
    }

    private func lookup() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }; history.record(q); vm.lookup(q)
    }
    
    private var whoisLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("WHOIS Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "What is WHOIS?", icon: "person.text.rectangle") { Text("WHOIS is a protocol for querying databases that store domain registration info.") }
                }.padding(24)
            }
        }.frame(width: 500, height: 600)
    }
}

struct WhoisLine: Identifiable {
    let id = UUID(); let raw: String
    var label: String? {
        guard raw.contains(":"), !raw.hasPrefix("%"), !raw.hasPrefix("#"), !raw.hasPrefix(">>>") else { return nil }
        return raw.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces)
    }
    var value: String? {
        guard label != nil else { return nil }
        return raw.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
    }
}

@MainActor
class WhoisViewModel: ObservableObject {
    @Published var lines: [WhoisLine] = []; @Published var isRunning = false; @Published var error: String?
    private var process: Process?; deinit { process?.terminate() }
    func lookup(_ query: String) {
        cancel(); lines = []; error = nil; isRunning = true
        let p = Process(); let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/whois"); p.arguments = [query]
        p.standardOutput = pipe; p.standardError = Pipe()
        p.terminationHandler = { [weak self] _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            let parsed = text.components(separatedBy: "\n").map { WhoisLine(raw: $0) }
            Task { @MainActor [weak self] in guard let self else { return }; self.lines = parsed; self.isRunning = false }
        }
        process = p; do { try p.run() } catch { self.error = error.localizedDescription; isRunning = false }
    }
    func cancel() { process?.terminate(); process = nil; isRunning = false }
}
