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
            controlBar
                .padding(.bottom, 24)
            
            if let err = vm.error {
                errorBanner(err).padding(.bottom, 16)
            }
            
            if let result = vm.result {
                statsBar(result).padding(.bottom, 24)
                
                VStack(alignment: .leading, spacing: 20) {
                    if result.chain.count > 1 {
                        HStack {
                            Picker("Chain", selection: $selectedCertIndex) {
                                ForEach(result.chain.indices, id: \.self) { i in
                                    Text(result.chain[i].isLeaf ? "Leaf" : "Intermediate [\(i)]").tag(i)
                                }
                            }
                            .pickerStyle(.segmented).frame(maxWidth: 300)
                            Spacer()
                        }
                    }

                    if let cert = result.chain[safe: selectedCertIndex] {
                        certDetail(cert)
                    }
                }
                .frame(maxHeight: .infinity)
            } else if vm.isRunning {
                loadingState
            } else {
                emptyState
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) { sslLearningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("hostname or URL", text: $host)
                .textFieldStyle(.roundedBorder).controlSize(.large).frame(minWidth: 250).onSubmit(startInspection)
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in Button(h) { host = h; startInspection() } }
                            Divider()
                            Button("Clear History", role: .destructive) { history.clear() }
                        } label: { Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary) }
                        .menuStyle(.borderlessButton).frame(width: 28).padding(.trailing, 4)
                    }
                }

            HStack(spacing: 8) {
                Text("Port:").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                TextField("", text: $portText).textFieldStyle(.roundedBorder).frame(width: 60)
            }

            Spacer()

            if let result = vm.result {
                Menu {
                    Button("Copy SHA-256") {
                        if let cert = result.chain.first {
                            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(cert.sha256, forType: .string)
                        }
                    }
                } label: { Label("Report", systemImage: "doc.text.fill").font(.system(size: 13, weight: .medium)) }.buttonStyle(.bordered)
            }

            Button(action: startInspection) {
                HStack(spacing: 6) { Image(systemName: vm.isRunning ? "stop.fill" : "play.fill"); Text(vm.isRunning ? "Stop" : "Inspect") }.font(.system(size: 13, weight: .medium)).frame(minWidth: 70)
            }.buttonStyle(.borderedProminent).tint(vm.isRunning ? .red : .accentColor).disabled(!vm.isRunning && host.isEmpty)
            
            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
        }
    }

    private func statsBar(_ r: CertResult) -> some View {
        HStack(spacing: 12) {
            if let tls = r.tlsVersion { StatCard(title: "TLS Version", value: tls, icon: "shield.fill", color: .green) }
            StatCard(title: "Chain", value: "\(r.chain.count)", icon: "link")
            if let days = r.chain.first?.daysRemaining {
                StatCard(title: "Expiry", value: "\(days)", unit: "days", icon: "calendar", color: days < 30 ? .orange : .primary)
            }
            Spacer()
        }
    }

    private func certDetail(_ cert: CertInfo) -> some View {
        VStack(spacing: 16) {
            infoSection("Subject & Issuer") {
                kv("Subject", cert.subject)
                Divider().opacity(0.5)
                kv("Issuer", cert.issuer)
                Divider().opacity(0.5)
                kv("Key Type", cert.keyType)
                Divider().opacity(0.5)
                kv("Serial", cert.serialNumber)
            }
            infoSection("Validity") {
                if let d = cert.notBefore { kv("From", d.formatted(date: .abbreviated, time: .standard)) }
                Divider().opacity(0.5)
                if let d = cert.notAfter { kv("Until", d.formatted(date: .abbreviated, time: .standard)) }
            }
            if !cert.sans.isEmpty {
                infoSection("Subject Alternative Names (SAN)") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(cert.sans, id: \.self) { san in
                            Text(san).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).textSelection(.enabled)
                        }
                    }
                }
            }
            infoSection("Fingerprint (SHA-256)") {
                Text(cert.sha256).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary).textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private func infoSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundColor(.primary)
            VStack(alignment: .leading, spacing: 12) { content() }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func kv(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func errorBanner(_ msg: String) -> some View { Text(msg).foregroundColor(.red).font(.system(size: 12, weight: .medium)) }

    private var emptyState: some View {
        VStack { Spacer(); Text("No Target Selected").font(.headline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack { Spacer(); ProgressView(); Text("Inspecting certificate chain...").font(.subheadline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startInspection() {
        guard !host.isEmpty else { return }; history.record(host); vm.inspect(host: host, port: Int(portText) ?? 443)
    }

    private var sslLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("SSL/TLS Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) { GuideSection(title: "What is SSL?", icon: "lock.shield") { Text("Encryption protocol for secure web connections.") } }.padding(24) }
        }.frame(width: 500, height: 600)
    }
}

private extension Array { subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil } }
