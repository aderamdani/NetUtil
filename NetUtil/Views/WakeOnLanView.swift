import SwiftUI

struct WakeOnLanView: View {
    @Bindable var vm: WakeOnLanViewModel
    @State private var showLearningGuide = false

    private var macIsValid: Bool { WakeOnLan.parseMAC(vm.macAddress) != nil }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            moodBar
            ScrollView {
                VStack(spacing: 24) {
                    if let err = vm.error {
                        ErrorBanner(message: err)
                    }
                    optionsCard
                    if vm.lastSent == nil && vm.error == nil {
                        ToolStateView.empty(title: "No Packet Sent",
                                            subtitle: "Enter the MAC address of a sleeping machine and press Wake.",
                                            minHeight: 200)
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showLearningGuide) { HelpView(topic: "Wake on LAN") }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "power.circle")
                        .foregroundColor(.accentColor)
                        .imageScale(.large)
                    Text("Wake on LAN")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Wake on LAN Tool")

                Divider().frame(height: 16).padding(.horizontal, 4)

                TextField("AA:BB:CC:DD:EE:FF", text: $vm.macAddress)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 250)
                    .onSubmit { if macIsValid { vm.send() } }
                    .accessibilityLabel("MAC Address Input")

                Spacer()

                Button(action: { vm.send() }) {
                    Label("Wake", systemImage: "power")
                        .frame(minWidth: 70)
                }
                .buttonStyle(.glassProminent)
                .disabled(!macIsValid)
                .accessibilityLabel("Send Wake Packet")

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
            if let sent = vm.lastSent {
                return ("checkmark.circle.fill", .green,
                        "Magic packet sent to \(sent.mac.uppercased()) at \(sent.at.formatted(date: .omitted, time: .standard))")
            }
            if !vm.macAddress.isEmpty && !macIsValid {
                return ("exclamationmark.triangle.fill", .orange, "MAC address incomplete — expected 6 pairs like AA:BB:CC:DD:EE:FF")
            }
            return ("power.circle", .secondary, "Sends a UDP magic packet that wakes a sleeping machine on your network")
        }()
        return MoodBar(icon: icon, color: color, message: msg)
    }

    // MARK: - Options

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Broadcast Address").font(.subheadline).foregroundColor(.secondary)
                Spacer()
                TextField("255.255.255.255", text: $vm.broadcastAddress)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(width: 160)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("Broadcast Address")
            }
            .help("Where the magic packet is broadcast. 255.255.255.255 reaches the local segment; use a subnet broadcast like 192.168.1.255 to target a specific network.")
            Divider().opacity(0.5)
            HStack {
                Text("UDP Port").font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Stepper("\(vm.port)", value: $vm.port, in: 0...65535)
                    .frame(width: 100)
                    .accessibilityLabel("UDP Port")
            }
            .help("Wake-on-LAN convention is port 9 (discard); some devices listen on 7. The port rarely matters — most network cards inspect every broadcast frame.")
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }
}
