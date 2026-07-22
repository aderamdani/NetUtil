import SwiftUI

struct PortListenerView: View {
    @Bindable var vm: PortListenerViewModel
    @State private var portText = "8080"
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
                    if vm.events.isEmpty {
                        ToolStateView.empty(title: vm.isRunning ? "Waiting for Connections" : "Listener Stopped",
                                            subtitle: vm.isRunning
                                                ? "Connect from another device — e.g. nc \(hostHint) \(vm.port) — and it will appear here."
                                                : "Start the listener, then test inbound reachability from another machine.")
                    } else {
                        eventList
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Port Listener") }
    }

    private var hostHint: String { "<this-mac's-ip>" }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "ear")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Port Listener")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Port Listener Tool")

                Divider().frame(height: 16).padding(.horizontal, 4)

                TextField("Port", text: $portText)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 80)
                    .disabled(vm.isRunning)
                    .onChange(of: portText) { _, new in vm.port = Int(new) ?? 0 }
                    .accessibilityLabel("Port Number")

                Picker("", selection: $vm.proto) {
                    ForEach(PortListenerViewModel.Proto.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .disabled(vm.isRunning)
                .accessibilityLabel("Protocol")

                Spacer()

                Button(action: { vm.isRunning ? vm.stop() : vm.start() }) {
                    Label(vm.isRunning ? "Stop" : "Listen", systemImage: vm.isRunning ? "stop.fill" : "play.fill")
                        .frame(minWidth: 70)
                }
                .buttonStyle(.glassProminent)
                .tint(vm.isRunning ? .red : .accentColor)
                .disabled(!vm.isRunning && Int(portText) == nil)
                .accessibilityLabel(vm.isRunning ? "Stop Listener" : "Start Listener")

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
            if vm.isRunning {
                let n = vm.events.count
                return ("dot.radiowaves.left.and.right", .green,
                        "Listening on \(vm.proto.rawValue) port \(vm.port)" + (n > 0 ? "  —  \(n) connection\(n == 1 ? "" : "s") logged" : ""))
            }
            return ("ear", .secondary, "Tests inbound reachability — open a local port and watch who connects")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    // MARK: - Events

    private var eventList: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.events.enumerated()), id: \.element.id) { idx, event in
                HStack(spacing: 12) {
                    Text(event.time.formatted(date: .omitted, time: .standard))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(event.remote)
                        .font(.system(.subheadline, design: .monospaced))
                        .textSelection(.enabled)
                    Text(event.detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                if idx < vm.events.count - 1 {
                    Divider().opacity(0.5)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
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
