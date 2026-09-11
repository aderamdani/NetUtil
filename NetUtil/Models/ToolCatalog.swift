import Foundation
import Observation

/// Availability store for tools. Disabled tools are hidden from the
/// sidebar, shortcuts, and favorites, and their app-lifetime pollers stay
/// stopped (see `ToolStore.applyToolAvailability`). Core tools
/// (`canBeDisabled == false`) are always available.
@MainActor
@Observable
final class ToolCatalog {
    /// Persisted disabled-tool tokens (`Tool.persistenceKey`).
    private(set) var disabledKeys: Set<String>

    @ObservationIgnored private let store: UserDefaults
    @ObservationIgnored private let key: String
    @ObservationIgnored var onAvailabilityChange: ((Tool, Bool) -> Void)?

    init(store: UserDefaults = .standard, key: String = "com.netutil.disabledTools") {
        self.store = store
        self.key = key
        let known = Set(Tool.allCases.map(\.persistenceKey))
        let saved = Set(store.stringArray(forKey: key) ?? [])
        self.disabledKeys = saved.intersection(known).filter {
            Tool(persistenceKey: $0)?.canBeDisabled ?? false
        }
    }

    /// Every tool, in sidebar order.
    var availableTools: [Tool] { Tool.allCases.filter(isAvailable) }

    var availableKeys: Set<String> {
        Set(Tool.allCases.map(\.persistenceKey)).subtracting(disabledKeys)
    }

    func isAvailable(_ tool: Tool) -> Bool {
        !disabledKeys.contains(tool.persistenceKey)
    }

    func setAvailable(_ tool: Tool, _ available: Bool) {
        guard tool.canBeDisabled else { return }
        if available {
            disabledKeys.remove(tool.persistenceKey)
        } else {
            disabledKeys.insert(tool.persistenceKey)
        }
        save()
        onAvailabilityChange?(tool, available)
    }

    func availableTools(in group: ToolGroup) -> [Tool] {
        Tool.allCases.filter { $0.group == group && isAvailable($0) }
    }

    /// Re-reads the store (e.g. after a settings import) and notifies for
    /// changed tools so `ToolStore` can start/stop matching monitors.
    func reload() {
        let known = Set(Tool.allCases.map(\.persistenceKey))
        let fresh = Set(store.stringArray(forKey: key) ?? [])
            .intersection(known)
            .filter { Tool(persistenceKey: $0)?.canBeDisabled ?? false }
        let changed = disabledKeys.symmetricDifference(fresh)
        disabledKeys = fresh
        for changedKey in changed {
            guard let tool = Tool(persistenceKey: changedKey) else { continue }
            onAvailabilityChange?(tool, !fresh.contains(changedKey))
        }
    }

    private func save() {
        store.set(Array(disabledKeys), forKey: key)
    }
}
