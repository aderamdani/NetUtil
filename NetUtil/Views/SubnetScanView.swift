import SwiftUI
import AppKit

struct SubnetScanView: View {
    @State private var viewModel = SubnetScanViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            controlBar
            statusMoodBar
            statsHeader
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredResults) { result in
                        resultRow(result)
                        Divider().opacity(0.5)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
    
    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("192.168.1.0/24", text: $viewModel.cidrInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            
            Picker("Speed", selection: $viewModel.batchSize) {
                Text("Normal").tag(8)
                Text("Fast").tag(16)
                Text("Aggressive").tag(32)
            }
            .frame(width: 120)
            
            Picker("Filter", selection: $viewModel.filterMode) {
                ForEach(SubnetScanViewModel.FilterMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .frame(width: 120)
            
            Button(viewModel.isScanning ? "Stop" : "Scan") {
                if viewModel.isScanning { viewModel.stopScan() }
                else { Task { await viewModel.startScan() } }
            }
            .keyboardShortcut("s", modifiers: .command)
            
            Spacer()
            
            Menu("Export", systemImage: "square.and.arrow.up") {
                Button("Export CSV") { /* TODO */ }
                Button("Export PDF") { /* TODO */ }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(12)
        .background(.regularMaterial)
    }
    
    private var statusMoodBar: some View {
        HStack {
            if viewModel.isScanning {
                Label("Scanning...", systemImage: "arrow.clockwise")
                    .foregroundColor(.blue)
            } else if viewModel.scanStats.alive > 0 {
                Label("Network Healthy — \(viewModel.scanStats.alive) hosts responding", systemImage: "checkmark.shield.fill")
                    .foregroundColor(.green)
            } else {
                Label("No Hosts Found — check CIDR", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption.bold())
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
    }
    
    private var statsHeader: some View {
        HStack {
            StatCard(title: "Total IPs", value: "\(viewModel.scanStats.total)", icon: "list.number")
            StatCard(title: "Alive", value: "\(viewModel.scanStats.alive)", icon: "checkmark.circle")
            StatCard(title: "Unreachable", value: "\(viewModel.scanStats.unreachable)", icon: "xmark.circle")
            StatCard(title: "Duration", value: viewModel.scanDuration, icon: "timer")
        }
        .padding(16)
    }
    
    private func resultRow(_ result: SubnetScanResult) -> some View {
        HStack {
            Text(result.ip).font(.system(.caption, design: .monospaced))
            Spacer()
            Text(result.hostname ?? "—").font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
            Spacer()
            if let mac = result.macAddress {
                Text(mac).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
            }
            Text(result.status.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(result.status == .alive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(4)
            Text(result.rtt != nil ? String(format: "%.2f ms", result.rtt!) : "-")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .contextMenu {
            if result.status == .alive {
                Button("Ping") { /* TODO */ }
                Button("Port Scan") { /* TODO */ }
                Button("Traceroute") { /* TODO */ }
                Divider()
                Button("Copy IP") { copy(result.ip) }
                if let mac = result.macAddress { Button("Copy MAC") { copy(mac) } }
            }
        }
    }
    
    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
