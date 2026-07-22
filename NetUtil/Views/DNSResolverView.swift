import SwiftUI

struct DNSResolverView: View {
    @Bindable var vm: DNSResolverViewModel
    @State private var showLearningGuide = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            moodBar
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        errorBanner(err)
                    }
                    if vm.effectiveResolvers.isEmpty {
                        if !vm.isRunning {
                            ToolStateView.empty(title: "No Resolvers Found",
                                                subtitle: "macOS reports the DNS servers it will actually query — press Refresh to read the current configuration.")
                        }
                    } else {
                        resolverList
                    }
                }
                .padding(24)
            }
        }
        .onAppear { if vm.resolvers.isEmpty { vm.start() } }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "DNS Resolver") }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("DNS Resolver")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("DNS Resolver Tool")

                Spacer()

                if !vm.effectiveResolvers.isEmpty {
                    ReportMenuButton(
                        onExportPDF: { Exporter.saveDNSResolverPDF(resolvers: vm.effectiveResolvers) },
                        onExportCSV: {
                            let ts = DateFormatter(); ts.dateFormat = "yyyyMMdd-HHmmss"
                            Exporter.save(string: Exporter.csvString(from: vm.effectiveResolvers),
                                          defaultName: "NetUtil-DNSResolver-\(ts.string(from: Date())).csv",
                                          ext: "csv")
                        }
                    )
                }

                Button { vm.start() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(vm.isRunning)
                .help("Re-read the DNS configuration and re-test each server's latency.")
                .accessibilityLabel("Refresh DNS Resolvers")

                Button { showLearningGuide = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Show Help Guide")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Divider()
        }
    }

    private var moodBar: some View {
        let (icon, color, msg): (String, Color, String) = {
            if vm.isRunning { return ("hourglass", .accentColor, "Reading DNS configuration and testing resolver latency...") }
            guard let primary = vm.primaryResolver, let ns = primary.nameservers.first else {
                return ("server.rack", .secondary, "Shows the DNS servers macOS actually queries, and how fast each one responds")
            }
            let latency = primary.latencyMs[ns].map { String(format: "%.0f ms", $0) } ?? "unreachable"
            return (primary.isReachable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    primary.isReachable ? .green : .orange,
                    "Primary resolver: \(ns) (\(latency))")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    // MARK: - Resolver List

    private var resolverList: some View {
        VStack(spacing: 12) {
            ForEach(vm.effectiveResolvers) { resolver in
                resolverCard(resolver)
            }
        }
    }

    private func resolverCard(_ resolver: DNSResolverEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(resolver.domain ?? "General (all domains)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                scopeBadge(resolver)
                reachabilityBadge(resolver)
            }

            ForEach(resolver.nameservers, id: \.self) { ns in
                HStack {
                    Image(systemName: "network")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(ns)
                        .font(.system(.subheadline, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    if let ms = resolver.latencyMs[ns] {
                        Text(String(format: "%.0f ms", ms))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(ms < 50 ? .green : (ms < 150 ? .orange : .red))
                    } else {
                        Text("no response")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            if let interface = resolver.interface {
                Text("Interface: \(interface)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }

    private func scopeBadge(_ resolver: DNSResolverEntry) -> some View {
        Text(resolver.scopeLabel)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(.secondary)
    }

    private func reachabilityBadge(_ resolver: DNSResolverEntry) -> some View {
        Text(resolver.isReachable ? "Reachable" : "Not Reachable")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((resolver.isReachable ? Color.green : Color.red).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            .foregroundColor(resolver.isReachable ? .green : .red)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(msg).font(.callout)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
