import SwiftUI
import Observation

struct SubnetCalculatorView: View {
    @Bindable var vm: SubnetViewModel
    @Environment(ToolStore.self) private var tools
    @State private var history = HostHistory.shared
    @State private var showLearningGuide = false
    
    var body: some View {
        VStack(spacing: 0) {
            controlBar
            moodBar

            ScrollView {
                VStack(spacing: 24) {
                    if let result = vm.result {
                        interpretationSection(result)
                        
                        statsBarSection(result)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Network Parameters", icon: "network")
                            resultsGrid(result)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Bitwise Representation", icon: "number.square")
                            binarySection(result)
                        }
                    } else {
                        emptyState
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Subnet Calculator") }
        .onAppear { vm.applyDetectedDefault(from: tools.primaryInterface) }
    }

    // MARK: - Components

    private var controlBar: some View {
        ToolControlBar(icon: "number.square", title: "Subnet Calculator",
                       host: $vm.ipAddress, placeholder: "IP Address",
                       textFieldAccessibilityLabel: "IP Address Input",
                       history: history, onSubmit: { vm.calculate() },
                       onSelectHistory: { h in vm.updateIP(h) }) {
            HStack(spacing: 12) {
                GlassEffectContainer {
                    HStack(spacing: 4) {
                        Text("Prefix")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: $vm.prefix) {
                            ForEach(0...32, id: \.self) { p in
                                Text("/\(p)").tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 70)
                        .onChange(of: vm.prefix) { vm.calculate() }
                        .accessibilityLabel("Network Prefix Length")
                    }
                    
                    Slider(value: Binding(get: { Double(vm.prefix) }, set: { vm.updatePrefix(Int($0)) }), in: 0...32, step: 1)
                        .frame(width: 120)
                        .tint(.accentColor)
                        .accessibilityLabel("Adjust Prefix Length")

                    if let result = vm.result {
                        ReportMenuButton(
                            onExportPDF: { Exporter.saveSubnetCalcPDF(result: result) },
                            onExportCSV: {
                                let date = DateFormatter(); date.dateFormat = "yyyyMMdd-HHmmss"
                                Exporter.save(string: Exporter.csvString(from: result), defaultName: "NetUtil-SubnetCalc-\(date.string(from: Date())).csv", ext: "csv")
                            },
                            onCopySummary: {
                                let summary = "Network: \(result.networkAddress)\nBroadcast: \(result.broadcastAddress)\nRange: \(result.firstHost) - \(result.lastHost)\nTotal Hosts: \(result.totalHosts)"
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(summary, forType: .string)
                            }
                        )
                    }
                }

                Button { showLearningGuide = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Show Help Guide")
            }
        }
    }
    
    private var moodBar: some View {
        if let r = vm.result {
            return MoodBar(icon: "number.square", color: .green,
                           message: "\(r.address)/\(r.prefix) · class \(r.ipClass) · \(r.usableHosts) usable hosts · \(r.mask)")
        } else {
            return MoodBar(icon: "number.square", color: .secondary,
                           message: "Enter an IPv4 address to calculate subnet topology")
        }
    }

    private func interpretationSection(_ r: SubnetResult) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Text(r.ipClass)
                    .foregroundColor(.accentColor)
                    .font(.subheadline.weight(.bold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("IPv4 Class \(r.ipClass) Network")
                    .font(.headline)
                Text("Calculated for \(r.address) with a /\(r.prefix) prefix.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("IPv4 Class \(r.ipClass) Network for \(r.address) with prefix \(r.prefix).")
            
            Spacer()
        }
    }

    private func statsBarSection(_ r: SubnetResult) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "Total Addresses", value: "\(r.totalHosts)", icon: "network")
            StatCard(title: "Usable Hosts", value: "\(r.usableHosts)", icon: "checkmark.shield.fill", color: .green)
            StatCard(title: "Subnet Mask", value: r.mask, icon: "rectangle.split.3x3.fill", color: .blue)
        }
    }

    private func resultsGrid(_ r: SubnetResult) -> some View {
        let items: [(String, String, String)] = [
            ("Network ID", r.networkAddress, "network"),
            ("Broadcast", r.broadcastAddress, "antenna.radiowaves.left.and.right"),
            ("First Host", r.firstHost, "arrow.right.to.line"),
            ("Last Host", r.lastHost, "arrow.left.to.line"),
            ("Wildcard", r.wildcardMask, "scissors"),
            ("Prefix Len", "/\(r.prefix)", "tag.fill")
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items, id: \.0) { label, value, icon in
                DetailCard(label: label, value: value, icon: icon)
            }
        }
    }

    private func binarySection(_ r: SubnetResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Subnet Mask Topology")
                    .font(.system(.caption2, design: .default).weight(.bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(r.prefix) bits masked · \(32 - r.prefix) host bits")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Text(r.binaryMask)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundColor(.primary)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
                .accessibilityLabel("Binary mask visualization: \(r.binaryMask)")
        }
    }

    private var emptyState: some View {
        ToolStateView.empty(title: "No IP Address Provided",
                            subtitle: "Enter an IPv4 address to analyze its subnet topology and host range.")
    }
}

