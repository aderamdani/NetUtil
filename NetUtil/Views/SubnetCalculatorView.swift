import SwiftUI
import Observation

struct SubnetCalculatorView: View {
    @Bindable var vm: SubnetViewModel
    @State private var history = HostHistory.shared
    @State private var showLearningGuide = false
    
    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            ScrollView {
                VStack(spacing: 24) {
                    if let result = vm.result {
                        interpretationSection(result)
                        
                        statsBarSection(result)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader("Network Parameters", icon: "network")
                            resultsGrid(result)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader("Bitwise Representation", icon: "number.square")
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
    }

    // MARK: - Components

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "number.square")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Subnet Calculator")
                        .font(.headline)
                }
                
                Divider().frame(height: 16).padding(.horizontal, 4)
                
                TextField("IP Address", text: $vm.ipAddress)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 250)
                    .onSubmit { vm.calculate() }
                    .overlay(alignment: .trailing) {
                        if !history.hosts.isEmpty {
                            Menu {
                                ForEach(history.hosts, id: \.self) { h in
                                    Button(h) { vm.updateIP(h) }
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
                    HStack(spacing: 12) {
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
                        }
                        
                        Slider(value: Binding(get: { Double(vm.prefix) }, set: { vm.updatePrefix(Int($0)) }), in: 0...32, step: 1)
                            .frame(width: 120)
                            .tint(.accentColor)
                    }

                    if let result = vm.result {
                        Button {
                            let summary = "Network: \(result.networkAddress)\nBroadcast: \(result.broadcastAddress)\nRange: \(result.firstHost) - \(result.lastHost)\nTotal Hosts: \(result.totalHosts)"
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(summary, forType: .string)
                        } label: {
                            Label("Copy Info", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)
                    }

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
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(.accentColor).font(.system(.caption2, design: .default).weight(.bold))
            Text(title).font(.system(.caption2, design: .default).weight(.bold)).foregroundColor(.secondary)
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
                    .font(.system(size: 14, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("IPv4 Class \(r.ipClass) Network")
                    .font(.headline)
                Text("Calculated for \(r.address) with a /\(r.prefix) prefix.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
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
                SubnetDetailCard(label: label, value: value, icon: icon)
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
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Text(r.binaryMask)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundColor(.primary)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No IP Address Provided")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Enter an IPv4 address to analyze its subnet topology and host range.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}

struct SubnetDetailCard: View {
    let label: String
    let value: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.accentColor)
                Text(label)
                    .font(.system(.caption2, design: .default).weight(.bold))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .lineLimit(1)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }
}
