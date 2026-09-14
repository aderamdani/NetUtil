import Foundation
import Observation

/// A named set of latency / loss alert thresholds. Persisted in UserDefaults
/// so a user can switch between e.g. "Gaming" and "Work" without opening
/// Settings.
struct ThresholdPreset: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let rttWarn: Double
    let rttCrit: Double
    let lossAlert: Double
    var isBuiltIn: Bool = false
}

@Observable
@MainActor
final class ThresholdPresets {
    static let builtIns: [ThresholdPreset] = [
        ThresholdPreset(name: "Default", rttWarn: 20, rttCrit: 100, lossAlert: 10, isBuiltIn: true),
        ThresholdPreset(name: "Gaming", rttWarn: 30, rttCrit: 80, lossAlert: 2, isBuiltIn: true),
        ThresholdPreset(name: "Work", rttWarn: 60, rttCrit: 150, lossAlert: 5, isBuiltIn: true)
    ]

    private(set) var custom: [ThresholdPreset] = []
    private let key = "com.netutil.thresholdPresets"

    var all: [ThresholdPreset] { Self.builtIns + custom }

    init() { load() }

    /// Writes the preset's limits into the shared threshold defaults. The
    /// tools' `@AppStorage` bindings observe these keys, so views update live.
    func apply(_ preset: ThresholdPreset) {
        let defaults = UserDefaults.standard
        defaults.set(preset.rttWarn, forKey: "rttWarnThreshold")
        defaults.set(preset.rttCrit, forKey: "rttCritThreshold")
        defaults.set(preset.lossAlert, forKey: "lossAlertThreshold")
    }

    /// The preset matching the current thresholds, or a synthetic "Custom".
    func current() -> ThresholdPreset {
        let defaults = UserDefaults.standard
        let warn = defaults.object(forKey: "rttWarnThreshold") as? Double ?? 20
        let crit = defaults.object(forKey: "rttCritThreshold") as? Double ?? 100
        let loss = defaults.object(forKey: "lossAlertThreshold") as? Double ?? 10
        if let match = all.first(where: { $0.rttWarn == warn && $0.rttCrit == crit && $0.lossAlert == loss }) {
            return match
        }
        return ThresholdPreset(name: "Custom", rttWarn: warn, rttCrit: crit, lossAlert: loss)
    }

    func saveCurrent(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let defaults = UserDefaults.standard
        let preset = ThresholdPreset(
            name: trimmed,
            rttWarn: defaults.object(forKey: "rttWarnThreshold") as? Double ?? 20,
            rttCrit: defaults.object(forKey: "rttCritThreshold") as? Double ?? 100,
            lossAlert: defaults.object(forKey: "lossAlertThreshold") as? Double ?? 10)
        custom.removeAll { $0.name == trimmed }
        custom.append(preset)
        save()
    }

    func delete(_ preset: ThresholdPreset) {
        guard !preset.isBuiltIn else { return }
        custom.removeAll { $0.name == preset.name }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ThresholdPreset].self, from: data) else { return }
        custom = decoded
    }
}
