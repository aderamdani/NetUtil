import SwiftUI

struct SubnetCalculatorView: View {
    @ObservedObject var vm: SubnetViewModel
    @StateObject private var history = HostHistory.shared
    @State private var showLearningGuide = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            controlBar.padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if let result = vm.result {
                        interpretationHeader(result)
                        statsBar(result).padding(.bottom, 8)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader("Network Parameters")
                            resultsGrid(result)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeader("Binary Representation")
                            binaryView(result)
                        }
                    } else {
                        emptyState
                    }
                }
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) { subnetLearningGuideSheet }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("IP Address", text: $vm.ipAddress)
                .textFieldStyle(.roundedBorder).controlSize(.large).frame(width: 250).onSubmit { vm.calculate() }
                .overlay(alignment: .trailing) {
                    if !history.hosts.isEmpty {
                        Menu {
                            ForEach(history.hosts, id: \.self) { h in Button(h) { vm.updateIP(h) } }
                            Divider()
                            Button("Clear History", role: .destructive) { history.clear() }
                        } label: { Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary) }.menuStyle(.borderlessButton).frame(width: 28).padding(.trailing, 4)
                    }
                }

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("Prefix:").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    Picker("", selection: $vm.prefix) { ForEach(0...32, id: \.self) { p in Text("/\(p)").tag(p) } }
                    .pickerStyle(.menu).frame(width: 80).onChange(of: vm.prefix) { vm.calculate() }
                }
                Slider(value: Binding(get: { Double(vm.prefix) }, set: { vm.updatePrefix(Int($0)) }), in: 0...32, step: 1).frame(width: 150).tint(.accentColor)
            }

            Spacer()

            if let result = vm.result {
                Button {
                    let summary = "Network: \(result.networkAddress)\nBroadcast: \(result.broadcastAddress)\nRange: \(result.firstHost) - \(result.lastHost)\nTotal Hosts: \(result.totalHosts)"
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(summary, forType: .string)
                } label: { Label("Copy Info", systemImage: "doc.on.clipboard").font(.system(size: 13, weight: .medium)) }.buttonStyle(.bordered)
            }

            Button { showLearningGuide = true } label: { Image(systemName: "questionmark.circle") }.buttonStyle(.borderless)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View { Text(title).font(.headline).foregroundColor(.primary) }

    private func interpretationHeader(_ r: SubnetResult) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "number.square.fill").font(.title2).foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("IPv4 Class \(r.ipClass) Network").font(.headline)
                Text("Calculated for \(r.address) with a /\(r.prefix) prefix.").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }.padding(.bottom, 8)
    }

    private func statsBar(_ r: SubnetResult) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "Total Hosts", value: "\(r.totalHosts)", icon: "laptopcomputer")
            StatCard(title: "Usable Hosts", value: "\(r.usableHosts)", icon: "checkmark.shield.fill", color: .primary)
            StatCard(title: "Subnet Mask", value: r.mask, icon: "rectangle.split.3x3.fill", color: .blue)
            Spacer()
        }
    }

    private func resultsGrid(_ r: SubnetResult) -> some View {
        let items: [(String, String, String)] = [
            ("Network ID", r.networkAddress, "network"), ("Broadcast", r.broadcastAddress, "antenna.radiowaves.left.and.right"),
            ("First Host", r.firstHost, "arrow.right.to.line"), ("Last Host", r.lastHost, "arrow.left.to.line"),
            ("Wildcard", r.wildcardMask, "scissors"), ("IP Class", r.ipClass, "tag.fill")
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items, id: \.0) { label, value, icon in SubnetDetailCard(label: label, value: value, icon: icon) }
        }
    }

    private func binaryView(_ r: SubnetResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Subnet Mask Bits").font(.system(.subheadline, design: .monospaced).weight(.medium)).foregroundColor(.secondary)
                Spacer()
                Text("\(r.prefix) ones, \(32 - r.prefix) zeros").font(.caption.weight(.medium)).foregroundColor(.secondary)
            }
            Text(r.binaryMask).font(.system(.title3, design: .monospaced).weight(.medium)).foregroundColor(.primary).padding(16).frame(maxWidth: .infinity, alignment: .center).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View {
        VStack { Spacer(); Text("No IP Address Provided").font(.headline).foregroundColor(.secondary); Spacer() }.frame(maxWidth: .infinity, minHeight: 150)
    }
    
    private var subnetLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Subnetting Guide").font(.title2.bold()); Spacer(); Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent) }.padding(24)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 24) { GuideSection(title: "CIDR Notation", icon: "number") { Text("Prefix length routing.") } }.padding(24) }
        }.frame(width: 500, height: 600)
    }
}

struct SubnetDetailCard: View {
    let label: String; let value: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption.weight(.medium)).foregroundColor(.secondary)
            Text(value).font(.system(.body, design: .monospaced)).lineLimit(1).textSelection(.enabled)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
