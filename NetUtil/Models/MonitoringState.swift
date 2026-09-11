import Foundation

/// App-lifetime monitoring tier. `.suspended` stops every poller so an
/// occluded app with no live consumer costs zero wakeups; on resume the
/// bandwidth sampler lump-captures raw byte deltas, keeping daily totals
/// exact without per-tick polling.
enum MonitoringState: Equatable, Sendable {
    case active
    case reduced
    case suspended

    /// Pure tier decision — no NSApp dependency, fully unit-testable.
    /// - Parameters:
    ///   - visible: any window reports `.visible` occlusion state.
    ///   - regular: activation policy is `.regular` (docked, not accessory).
    ///   - hasLiveConsumer: something background-visible needs live samples
    ///     (the menu-bar label's ↓/↑ readout when `menuBarShowTraffic` is on).
    static func targetState(visible: Bool, regular: Bool, hasLiveConsumer: Bool) -> MonitoringState {
        if visible && regular { return .active }
        if hasLiveConsumer { return .reduced }
        return .suspended
    }
}

/// Owns the current tier; `transition(to:)` reports whether pollers must be
/// touched. A repeat request for the current tier is a no-op, avoiding
/// redundant stop/start churn on duplicate notifications.
struct MonitoringStateController: Sendable {
    private(set) var current: MonitoringState = .active

    mutating func transition(to next: MonitoringState) -> Bool {
        guard next != current else { return false }
        current = next
        return true
    }
}
