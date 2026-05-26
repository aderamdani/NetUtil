import SwiftUI
import Combine

struct WhoisView: View {
    @ObservedObject var vm: WhoisViewModel
    @StateObject private var history = HostHistory.shared
    @State private var query = ""
    @State private var filterText = ""

    private var displayedLines: [WhoisLine] {
        guard !filterText.isEmpty else { return vm.lines }
        let q = filterText.lowercased()
        return vm.lines.filter { $0.raw.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlBar
            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.caption)
            }
            if vm.isRunning {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Querying…").font(.caption).foregroundColor(.secondary)
                }
            }
            if !vm.lines.isEmpty {
                filterBar
                outputView
            } else if !vm.isRunning {
                emptyState
            }
        }
        .padding()
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundColor(.secondary)
                .font(.caption)
            TextField("Filter…", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
            if !filterText.isEmpty {
                Text("\(displayedLines.count) of \(vm.lines.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Button { filterText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            Spacer()
        }
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                TextField("Domain or IP", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                    .onSubmit { lookup() }
                if !history.hosts.isEmpty {
                    Menu {
                        ForEach(history.hosts, id: \.self) { h in
                            Button(h) { query = h; lookup() }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                }
            }

            Spacer()

            if !vm.lines.isEmpty {
                Button {
                    Exporter.save(string: vm.lines.map(\.raw).joined(separator: "\n"),
                                  defaultName: "whois-\(query).txt", ext: "txt")
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
            }

            Button(vm.isRunning ? "Cancel" : "Lookup") {
                if vm.isRunning { vm.cancel() } else { lookup() }
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && query.isEmpty)
            .keyboardShortcut(.return)
        }
    }

    private var outputView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(displayedLines) { line in
                    HStack(spacing: 0) {
                        if let label = line.label {
                            Text(label + ":")
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundColor(.accentColor)
                                .frame(width: 200, alignment: .leading)
                            Text(line.value ?? "")
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text(line.raw)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(line.raw.hasPrefix("%") || line.raw.hasPrefix("#") ? .secondary : .primary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 1)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass.circle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Enter a domain or IP address")
                .foregroundColor(.secondary)
                .font(.callout)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }

    private func lookup() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        history.record(q)
        vm.lookup(q)
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
