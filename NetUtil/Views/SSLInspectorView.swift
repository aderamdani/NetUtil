import SwiftUI

struct SSLInspectorView: View {
    @ObservedObject var vm: SSLInspectorViewModel
    @StateObject private var history = HostHistory.shared
    @State private var host = ""
    @State private var portText = "443"
    @State private var selectedCertIndex = 0
    @State private var showLearningGuide = false

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
                    
                    if let result = vm.result {
                        // 2. INTERPRETATION HEADER
                        interpretationHeader(result)
                        
                        // 3. STATS BAR
                        statsBar(result)
                        
                        // 4. CERT CONTENT
                        certContent(result)
                    } else if !vm.isRunning {
                        emptyState
                    }
                    
                    if vm.isRunning {
                        HStack(spacing: 12) {
                            ProgressView().controlSize(.small)
                            Text("Securing handshake and inspecting certificate chain...")
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
            sslLearningGuideSheet
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // 1. Target Input with History
            TextField("hostname or URL", text: $host)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(minWidth: 250)
                .help("Host to inspect SSL/TLS certificate.")
                .onSubmit(startInspection)
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in
                                Button(h) { host = h; startInspection() }
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

            // 2. Settings Group
            HStack(spacing: 8) {
                Text("Port:").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                TextField("", text: $portText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }

            Spacer()

            // 3. Action Group
            if let result = vm.result {
                Menu {
                    Button("Copy SHA-256 Fingerprint") {
                        if let cert = result.chain.first {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(cert.sha256, forType: .string)
                        }
                    }
                    Divider()
                    Button("Copy Host:Port") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("\(result.host):\(result.port)", forType: .string)
                    }
                } label: {
                    Label("Report", systemImage: "doc.text.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button(action: startInspection) {
                HStack(spacing: 6) {
                    if vm.isRunning {
                        Image(systemName: "stop.fill").font(.system(size: 11, weight: .bold))
                        Text("Stop")
                    } else {
                        Image(systemName: "play.fill")
                        Text("Inspect")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(vm.isRunning ? .red : .accentColor)
            .disabled(!vm.isRunning && host.isEmpty)
            
            Button { showLearningGuide = true } label: {
                Image(systemName: "book.fill").font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("SSL/TLS Learning Guide")
        }
    }
    
    private func interpretationHeader(_ r: CertResult) -> some View {
        HStack(alignment: .center, spacing: 12) {
            let isExpired = (r.chain.first?.daysRemaining ?? 0) <= 0
            Image(systemName: isExpired ? "xmark.shield.fill" : "lock.shield.fill")
                .font(.title2)
                .foregroundColor(isExpired ? .red : .green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isExpired ? "Insecure / Expired" : "Connection Secure")
                    .font(.headline)
                Text(isExpired ? "The remote certificate has expired or is invalid." : "TLS handshake established using modern encryption.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private func statsBar(_ r: CertResult) -> some View {
        HStack(spacing: 12) {
            if let tls = r.tlsVersion {
                StatCard(title: "TLS VERSION", value: tls, icon: "shield.fill", color: .green)
            }
            StatCard(title: "CHAIN LENGTH", value: "\(r.chain.count)", icon: "link")
            if let days = r.chain.first?.daysRemaining {
                StatCard(title: "EXPIRY", value: "\(days)", unit: "days", icon: "calendar", color: days < 30 ? .orange : .secondary)
            }
            Spacer()
        }
    }

    private func certContent(_ result: CertResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if result.chain.count > 1 {
                Picker("Certificate Chain", selection: $selectedCertIndex) {
                    ForEach(result.chain.indices, id: \.self) { i in
                        Text(result.chain[i].isLeaf ? "Leaf Certificate" : "Root/Intermediate [\(i)]")
                            .tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
            }

            if let cert = result.chain[safe: selectedCertIndex] {
                certDetail(cert)
            }
        }
    }

    private func certDetail(_ cert: CertInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            infoSection("Subject & Issuer") {
                kv("Subject", cert.subject)
                kv("Issuer", cert.issuer)
                kv("Key Type", cert.keyType)
                kv("Serial", cert.serialNumber)
            }
            
            infoSection("Validity Period") {
                if let d = cert.notBefore {
                    kv("Not Before", d.formatted(date: .abbreviated, time: .standard))
                }
                if let d = cert.notAfter {
                    kv("Not After", d.formatted(date: .abbreviated, time: .standard))
                }
            }
            
            if !cert.sans.isEmpty {
                infoSection("Subject Alternative Names") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(cert.sans, id: \.self) { san in
                            Text(san)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            infoSection("Security Fingerprint") {
                Text(cert.sha256)
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "lock.shield").font(.system(size: 32)).foregroundColor(.accentColor)
            }
            Text("Ready to audit security certificates. Enter a host and press Inspect.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.top, 40)
    }

    @ViewBuilder
    private func infoSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.secondary)
                .kerning(1)
            
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
        }
    }

    private func kv(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func startInspection() {
        guard !host.isEmpty else { return }
        history.record(host)
        vm.inspect(host: host, port: Int(portText) ?? 443)
    }

    private var sslLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SSL/TLS Learning Guide").font(.title2.bold())
                    Text("Learn how encryption secures the web.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "What is SSL/TLS?", icon: "lock.shield") {
                        Text("SSL (Secure Sockets Layer) and its successor TLS (Transport Layer Security) are protocols for establishing authenticated and encrypted links between networked computers.")
                    }
                    
                    GuideSection(title: "What is a Certificate?", icon: "doc.text.fill") {
                        Text("A digital certificate is like a virtual passport. It proves that the website you're visiting is actually owned by who they claim to be, verified by a Trusted Authority.")
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
