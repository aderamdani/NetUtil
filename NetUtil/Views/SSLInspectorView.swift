import SwiftUI

struct SSLInspectorView: View {
    @StateObject private var vm = SSLInspectorViewModel()
    @State private var host = ""
    @State private var portText = "443"
    @State private var selectedCertIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlBar
            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.caption)
            }
            if vm.isRunning {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Connecting…").font(.caption).foregroundColor(.secondary)
                }
            }
            if let result = vm.result {
                certContent(result)
            } else if !vm.isRunning {
                emptyState
            }
        }
        .padding()
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            TextField("hostname or URL", text: $host)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 240)
                .onSubmit { inspect() }

            HStack(spacing: 4) {
                Text("Port:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $portText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 52)
            }

            Spacer()

            Button(vm.isRunning ? "Cancel" : "Inspect") {
                if vm.isRunning { vm.cancel() } else { inspect() }
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isRunning ? .red : .accentColor)
            .keyboardShortcut(.return)
            .disabled(!vm.isRunning && host.isEmpty)
        }
    }

    private func certContent(_ result: CertResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.green)
                Text(result.host)
                    .font(.system(.body, design: .monospaced).bold())
                Text(":\(result.port)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text(result.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            if result.chain.count > 1 {
                Picker("Certificate", selection: $selectedCertIndex) {
                    ForEach(result.chain.indices, id: \.self) { i in
                        Text(result.chain[i].isLeaf ? "Leaf" : "Chain [\(i)]")
                            .tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
            }

            if let cert = result.chain[safe: selectedCertIndex] {
                certDetail(cert)
            }
        }
    }

    private func certDetail(_ cert: CertInfo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let days = cert.daysRemaining {
                    expiryBanner(days: days, notAfter: cert.notAfter)
                }
                infoSection("Subject & Issuer") {
                    kv("Subject", cert.subject)
                    kv("Issuer", cert.issuer)
                    kv("Key", cert.keyType)
                    kv("Serial", cert.serialNumber)
                }
                infoSection("Validity") {
                    if let d = cert.notBefore {
                        kv("Not Before", d.formatted(date: .abbreviated, time: .standard))
                    }
                    if let d = cert.notAfter {
                        kv("Not After", d.formatted(date: .abbreviated, time: .standard))
                    }
                }
                if !cert.sans.isEmpty {
                    infoSection("Subject Alternative Names") {
                        ForEach(cert.sans, id: \.self) { san in
                            Text(san)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
                infoSection("Fingerprint (SHA-256)") {
                    Text(cert.sha256)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func expiryBanner(days: Int, notAfter: Date?) -> some View {
        let (bg, fg, icon): (Color, Color, String) = {
            if days > 30 { return (.green.opacity(0.12), .green, "checkmark.shield") }
            if days > 7  { return (.orange.opacity(0.12), .orange, "exclamationmark.triangle") }
            return (.red.opacity(0.12), .red, "xmark.shield")
        }()
        return HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(fg)
            if days > 0 {
                Text("Expires in \(days) day\(days == 1 ? "" : "s")")
                    .font(.callout.bold())
                    .foregroundColor(fg)
            } else {
                Text("Expired \(-days) day\(-days == 1 ? "" : "s") ago")
                    .font(.callout.bold())
                    .foregroundColor(.red)
            }
            Spacer()
            if let d = notAfter {
                Text(d.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(fg)
            }
        }
        .padding(12)
        .background(bg)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func infoSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private func kv(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "lock.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Enter a hostname and press Inspect")
                .foregroundColor(.secondary)
                .font(.callout)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
    }

    private func inspect() {
        guard !host.isEmpty else { return }
        vm.inspect(host: host, port: Int(portText) ?? 443)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
