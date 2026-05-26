import SwiftUI

struct DNSView: View {
    @StateObject private var vm = DNSViewModel()
    @StateObject private var history = HostHistory.shared
    @State private var host = ""
    @State private var recordType = DNSRecordType.a
    @State private var server = DNSServer.system
    @State private var showRaw = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlBar
            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.caption)
            }
            if let result = vm.result {
                queryInfo(result)
            }
            HStack {
                Picker("", selection: $showRaw) {
                    Text("Records").tag(false)
                    Text("Raw").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                Spacer()
                if let result = vm.result, !result.records.isEmpty {
                    exportMenu(result)
                }
            }
            if showRaw {
                rawOutput
            } else {
                recordsTable
            }
        }
        .padding()
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                TextField("Hostname or IP", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                if !history.hosts.isEmpty {
                    Menu {
                        ForEach(history.hosts, id: \.self) { h in
                            Button(h) { host = h }
                        }
                        Divider()
                        Button("Clear History", role: .destructive) { history.clear() }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28)
                }
            }

            Picker("Type", selection: $recordType) {
                ForEach(DNSRecordType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .frame(width: 110)

            Picker("Server", selection: $server) {
                ForEach(DNSServer.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .frame(width: 190)

            Spacer()

            if vm.isRunning {
                ProgressView().scaleEffect(0.65)
            }

            Button(vm.isRunning ? "Cancel" : "Lookup") {
                if vm.isRunning {
                    vm.cancel()
                } else {
                    history.record(host)
                    vm.lookup(host: host, type: recordType, server: server)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && host.isEmpty)
            .keyboardShortcut(.return)
        }
    }

    private func queryInfo(_ result: DNSResult) -> some View {
        HStack(spacing: 16) {
            infoChip("Server", result.server)
            if let ms = result.queryTimeMs {
                infoChip("Query Time", "\(ms) ms")
                    .foregroundColor(ms < 50 ? .green : ms < 200 ? .orange : .red)
            }
            infoChip("Records", "\(result.records.count)")
            infoChip("Time", result.timestamp.formatted(.dateTime.hour().minute().second()))
        }
    }

    private func infoChip(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.body, design: .monospaced).bold())
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var recordsTable: some View {
        Group {
            if let result = vm.result, !result.records.isEmpty {
                Table(result.records) {
                    TableColumn("Name") { r in
                        Text(r.name)
                            .font(.system(.body, design: .monospaced))
                    }
                    TableColumn("TTL") { r in
                        Text("\(r.ttl)")
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(60)
                    TableColumn("Type") { r in
                        Text(r.type)
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(typeColor(r.type))
                    }
                    .width(65)
                    TableColumn("Value") { r in
                        Text(r.value)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            } else if vm.result != nil {
                VStack {
                    Spacer()
                    Text("No records found")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
            } else if !vm.isRunning {
                VStack {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Enter a hostname and press Lookup")
                        .foregroundColor(.secondary)
                        .font(.callout)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack {
                    Spacer()
                    ProgressView("Querying...")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    private var rawOutput: some View {
        ScrollView {
            Text(vm.rawOutput.isEmpty ? "No output yet" : vm.rawOutput)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .textSelection(.enabled)
        }
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }

    private func exportMenu(_ result: DNSResult) -> some View {
        Menu {
            Button("Export CSV") {
                let csv = exportCSV(result)
                Exporter.save(string: csv, defaultName: "dns-\(host).csv", ext: "csv")
            }
            Button("Copy All Values") {
                let values = result.records.map { $0.value }.joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(values, forType: .string)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
        .frame(width: 32)
    }

    private func exportCSV(_ result: DNSResult) -> String {
        var lines = ["name,ttl,type,value"]
        for r in result.records {
            lines.append("\(r.name),\(r.ttl),\(r.type),\"\(r.value)\"")
        }
        return lines.joined(separator: "\n")
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "A":     return .blue
        case "AAAA":  return .purple
        case "MX":    return .orange
        case "NS":    return .green
        case "CNAME": return .teal
        case "TXT":   return .secondary
        case "SOA":   return .brown
        case "PTR":   return .indigo
        default:      return .primary
        }
    }
}
