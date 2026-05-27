import SwiftUI

struct SubnetCalculatorView: View {
    @ObservedObject var vm: SubnetViewModel
    @StateObject private var history = HostHistory.shared
    @State private var showLearningGuide = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. STANDARD HEADER (Fixed Top)
            controlBar
                .padding(.bottom, 24)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let result = vm.result {
                        // 2. INTERPRETATION HEADER
                        interpretationHeader(result)
                        
                        // 3. STATS BAR
                        statsBar(result)
                        
                        // 4. CALCULATION RESULTS GRID
                        VStack(alignment: .leading, spacing: 12) {
                            Text("NETWORK PARAMETERS")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.secondary)
                                .kerning(1)
                            
                            resultsGrid(result)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BINARY REPRESENTATION")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.secondary)
                                .kerning(1)
                            
                            binaryView(result)
                        }
                    } else {
                        emptyState
                    }
                }
            }
        }
        .padding(32)
        .sheet(isPresented: $showLearningGuide) {
            subnetLearningGuideSheet
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            // 1. Target Input with History
            TextField("IP Address", text: $vm.ipAddress)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .frame(width: 250)
                .help("IP address to calculate subnet for.")
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

            // 2. Variable Settings (Prefix Slider/Picker)
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("Prefix:").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                    Picker("", selection: $vm.prefix) {
                        ForEach(0...32, id: \.self) { p in
                            Text("/\(p)").tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                    .onChange(of: vm.prefix) { vm.calculate() }
                }
                
                Slider(value: Binding(get: { Double(vm.prefix) }, set: { vm.updatePrefix(Int($0)) }), in: 0...32, step: 1)
                    .frame(width: 150)
                    .tint(.accentColor)
            }

            Spacer()

            // 3. Action Group
            if let result = vm.result {
                Menu {
                    Button("Copy Network Info") {
                        let summary = """
                        Subnet Summary for \(result.address)/\(result.prefix)
                        Network: \(result.networkAddress)
                        Broadcast: \(result.broadcastAddress)
                        Range: \(result.firstHost) - \(result.lastHost)
                        Total Hosts: \(result.totalHosts)
                        Usable: \(result.usableHosts)
                        """
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(summary, forType: .string)
                    }
                } label: {
                    Label("Report", systemImage: "doc.text.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button { showLearningGuide = true } label: {
                Image(systemName: "book.fill").font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Subnetting Guide")
        }
    }
    
    private func interpretationHeader(_ r: SubnetResult) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "number.square.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("IPv4 Class \(r.ipClass) Network")
                    .font(.headline)
                Text("Calculated network parameters for \(r.address) with a /\(r.prefix) prefix.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private func statsBar(_ r: SubnetResult) -> some View {
        HStack(spacing: 12) {
            StatCard(title: "TOTAL HOSTS", value: "\(r.totalHosts)", icon: "laptopcomputer")
            StatCard(title: "USABLE HOSTS", value: "\(r.usableHosts)", icon: "checkmark.shield.fill", color: .green)
            StatCard(title: "SUBNET MASK", value: r.mask, icon: "rectangle.split.3x3.fill", color: .blue)
            Spacer()
        }
    }

    private func resultsGrid(_ r: SubnetResult) -> some View {
        let items: [(String, String, String)] = [
            ("Network ID",    r.networkAddress,   "network"),
            ("Broadcast",     r.broadcastAddress, "antenna.radiowaves.left.and.right"),
            ("First Host",    r.firstHost,        "arrow.right.to.line"),
            ("Last Host",     r.lastHost,         "arrow.left.to.line"),
            ("Wildcard Mask", r.wildcardMask,      "scissors"),
            ("IP Class",      r.ipClass,           "tag.fill"),
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items, id: \.0) { label, value, icon in
                SubnetDetailCard(label: label, value: value, icon: icon)
            }
        }
    }

    private func binaryView(_ r: SubnetResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Subnet Mask BITS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(r.prefix) ones, \(32 - r.prefix) zeros")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.accentColor)
            }
            
            Text(r.binaryMask)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(.primary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.accentColor.opacity(0.05))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.1), lineWidth: 1))
        }
        .padding(18)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "number.square").font(.system(size: 32)).foregroundColor(.accentColor)
            }
            Text("Ready to calculate subnets. Enter an IP address and adjust the prefix slider.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.top, 40)
    }
    
    private var subnetLearningGuideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subnetting Learning Guide").font(.title2.bold())
                    Text("Learn how to divide networks using CIDR notation.").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { showLearningGuide = false }.buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GuideSection(title: "What is a Subnet?", icon: "network") {
                        Text("Subnetting is the practice of dividing a network into two or more smaller networks. It improves security and reduces network congestion.")
                    }
                    
                    GuideSection(title: "CIDR Notation", icon: "number") {
                        Text("Classless Inter-Domain Routing (CIDR) uses a slash followed by a number (e.g., /24) to represent the number of '1' bits in the subnet mask.")
                    }
                    
                    GuideSection(title: "Network vs Broadcast", icon: "antenna.radiowaves.left.and.right") {
                        VStack(alignment: .leading, spacing: 12) {
                            GuidePoint(title: "Network Address", desc: "The first address in a subnet, used to identify the network itself.")
                            GuidePoint(title: "Broadcast Address", desc: "The last address in a subnet, used to send data to all hosts simultaneously.")
                        }
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct SubnetDetailCard: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(.accentColor).font(.system(size: 10))
                Text(label.uppercased()).font(.system(size: 9, weight: .black)).foregroundColor(.secondary).kerning(0.5)
            }
            Text(value).font(.system(size: 13, weight: .bold, design: .monospaced)).lineLimit(1).textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
    }
}
