import SwiftUI
import AppKit

/// Compact menu for switching named alert-threshold presets (and saving the
/// current limits as a new one) without opening Settings.
struct ThresholdPresetMenu: View {
    @Environment(ToolStore.self) private var tools

    var body: some View {
        Menu {
            ForEach(tools.thresholdPresets.all) { preset in
                Button {
                    tools.thresholdPresets.apply(preset)
                } label: {
                    if preset.name == tools.thresholdPresets.current().name {
                        Label(preset.name, systemImage: "checkmark")
                    } else {
                        Text(preset.name)
                    }
                }
            }

            Divider()

            Button("Save Current…") { promptSave() }

            if !tools.thresholdPresets.custom.isEmpty {
                Menu("Delete") {
                    ForEach(tools.thresholdPresets.custom) { preset in
                        Button(preset.name, role: .destructive) {
                            tools.thresholdPresets.delete(preset)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28)
        .help("Alert threshold presets")
        .accessibilityLabel("Alert threshold presets")
    }

    private func promptSave() {
        let alert = NSAlert()
        alert.messageText = "Save Threshold Preset"
        alert.informativeText = "Name this set of latency and loss limits."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = "Preset name"
        alert.accessoryView = field
        if alert.runModal() == .alertFirstButtonReturn {
            tools.thresholdPresets.saveCurrent(named: field.stringValue)
        }
    }
}
