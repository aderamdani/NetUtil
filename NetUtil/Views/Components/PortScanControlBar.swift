import SwiftUI

struct PortScanControlBar: View {
    @Binding var host: String
    var isRunning: Bool
    @Binding var portRangeType: PortPreset
    @Binding var customPorts: String
    let onStart: () -> Void
    let onShowGuide: () -> Void
    let history: HostHistory
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Port Scanner")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Port Scanner Tool")
                
                Divider().frame(height: 16).padding(.horizontal, 4)
                
                TextField("Hostname or IP address", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .frame(width: 250)
                    .onSubmit(onStart)
                    .accessibilityLabel("Host Input")
                    .overlay(alignment: .trailing) {
                        if !history.hosts.isEmpty {
                            Menu {
                                ForEach(history.hosts, id: \.self) { h in
                                    Button(h) { host = h; onStart() }
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
                            .accessibilityLabel("Host History")
                        }
                    }

                Spacer()
                
                HStack(spacing: 12) {
                    Picker("", selection: $portRangeType) {
                        ForEach(PortPreset.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    .accessibilityLabel("Port Range Type")
                    
                    if portRangeType == .custom {
                        TextField("e.g. 80,443,3000-4000", text: $customPorts)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                            .accessibilityLabel("Custom Port Range")
                    }

                    Button(action: onStart) {
                        Label(isRunning ? "Stop" : "Scan", systemImage: isRunning ? "stop.fill" : "play.fill")
                            .frame(minWidth: 70)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isRunning ? .red : .accentColor)
                    .disabled(!isRunning && host.isEmpty)
                    .accessibilityLabel(isRunning ? "Stop Scanning" : "Start Scanning")
                    
                    Button(action: onShowGuide) {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Show Help Guide")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            
            Divider()
        }
    }
}

