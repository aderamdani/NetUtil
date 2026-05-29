import SwiftUI

struct SSLInspectorView: View {
    @ObservedObject var vm: SSLInspectorViewModel
    @StateObject private var history = HostHistory.shared
    @State private var host = ""
    @State private var portText = "443"
    @State private var selectedCertIndex = 0
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
                    }
                    
                    if let result = vm.result {
                        certificateHealthSection(result)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            chainSelector(result)
                            
                            if let cert = result.chain[safe: selectedCertIndex] {
                                certificateDetails(cert)
                            }
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
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "SSL/TLS Inspector") }
    }

    // MARK: - Components

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("SSL/TLS Inspector")
                        .font(.headline)
                }
                
                Divider().frame(height: 16).padding(.horizontal, 4)
                
                TextField("hostname or URL", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 280)
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

                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("Port")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.secondary)
                        TextField("", text: $portText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                    }

                    Button(action: startInspection) {
                        Label(vm.isRunning ? "Stop" : "Inspect", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isRunning ? .red : .accentColor)
                    .disabled(!vm.isRunning && host.isEmpty)
                    
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

    private func certificateHealthSection(_ r: CertResult) -> some View {
        HStack(spacing: 12) {
            let leaf = r.chain.first
            let isExpired = (leaf?.daysRemaining ?? 0) < 0
            
            StatCard(
                title: "Status",
                value: isExpired ? "Expired" : "Trusted",
                icon: isExpired ? "exclamationmark.shield.fill" : "checkmark.shield.fill",
                color: isExpired ? .red : .green
            )
            
            StatCard(
                title: "Chain Depth",
                value: "\(r.chain.count)",
                unit: "Certs",
                icon: "link"
            )
            
            if let days = leaf?.daysRemaining {
                StatCard(
                    title: "Expiry",
                    value: "\(abs(days))",
                    unit: days < 0 ? "days ago" : "days left",
                    icon: "calendar",
                    color: days < 7 ? .red : (days < 30 ? .orange : .primary)
                )
            }
            
            if let key = leaf?.keyType {
                StatCard(
                    title: "Security",
                    value: key,
                    icon: "key.fill",
                    color: isWeakKey(key) ? .orange : .primary
                )
            }
        }
    }

    private func chainSelector(_ result: CertResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Certificate Chain")
                .font(.system(.caption, design: .default).weight(.bold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 0) {
                ForEach(result.chain.indices, id: \.self) { i in
                    let cert = result.chain[i]
                    Button {
                        selectedCertIndex = i
                    } label: {
                        VStack(spacing: 4) {
                            Text(cert.isLeaf ? "End-Entity" : (i == result.chain.count - 1 ? "Root" : "Intermediate"))
                                .font(.system(size: 11, weight: .bold))
                            Text(cert.subject.components(separatedBy: "CN=").last?.components(separatedBy: ",").first ?? cert.subject)
                                .font(.system(size: 10))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedCertIndex == i ? Color.accentColor : Color.clear)
                        .foregroundColor(selectedCertIndex == i ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    
                    if i < result.chain.count - 1 {
                        Divider().frame(height: 24)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private func certificateDetails(_ cert: CertInfo) -> some View {
        VStack(spacing: 20) {
            detailGroup("Subject & Issuer") {
                kv("Common Name", cert.subject)
                kv("Issuer", cert.issuer)
                kv("Serial No.", cert.serialNumber)
            }
            
            detailGroup("Validity Period") {
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not Before").font(.caption2.bold()).foregroundColor(.secondary)
                        Text(cert.notBefore?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not After").font(.caption2.bold()).foregroundColor(.secondary)
                        Text(cert.notAfter?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor((cert.daysRemaining ?? 0) < 30 ? .orange : .primary)
                    }
                }
            }
            
            detailGroup("Public Key & Fingerprint") {
                kv("Key Algorithm", cert.keyType)
                kv("SHA-256", cert.sha256)
            }
            
            if !cert.sans.isEmpty {
                detailGroup("Subject Alternative Names (\(cert.sans.count))") {
                    FlowLayout(spacing: 8) {
                        ForEach(cert.sans, id: \.self) { san in
                            Text(san)
                                .font(.system(size: 10, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.caption, design: .default).weight(.bold))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private func kv(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
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
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No Target Inspected")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Enter a domain to audit its SSL/TLS certificate chain.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Inspecting Security Chain...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func startInspection() {
        let cleanHost = host.trimmingCharacters(in: .whitespaces)
        guard !cleanHost.isEmpty else { return }
        history.record(cleanHost)
        vm.inspect(host: cleanHost, port: Int(portText) ?? 443)
    }
    
    private func isWeakKey(_ key: String) -> Bool {
        if key.contains("RSA") {
            if let sizeStr = key.components(separatedBy: "-").last, let size = Int(sizeStr) {
                return size < 2048
            }
        }
        return false
    }
}

// Simple FlowLayout for SANs
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > width {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = max(totalHeight, currentY + lineHeight)
        }
        return CGSize(width: width, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private extension Array { subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil } }
