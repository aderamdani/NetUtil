import Foundation
import Combine
import Observation

// MARK: - ViewModel

@Observable
@MainActor
final class SpeedTestViewModel: SpeedTestDelegate {
    var kind: SpeedTestKind = .speed
    
    // Delegate state
    var phase: SpeedTestPhase = .idle
    var progress: Double = 0
    
    // Speed live values
    var downloadMbps: Double = 0
    var uploadMbps: Double = 0
    var pingMs: Double = 0
    var jitterMs: Double = 0

    // Browsing live values
    var browsingAvgMs: Double = 0
    var browsingMedianTtfb: Double = 0
    var browsingProcessed: Int = 0

    // Gaming live values
    var gameMedianMs: Double = 0
    var gameP99Ms: Double = 0
    var gameJitterMs: Double = 0
    var gameLossPct: Double = 0

    // Streaming live values
    var streamAvgMbps: Double = 0
    var streamMinMbps: Double = 0
    var streamTier: String = "—"
    
    // Internal state
    private(set) var lastResult: SpeedTestResult?
    private(set) var history: [SpeedTestResult] = []
    private(set) var error: String?

    private var isRunning = false
    private var pendingConnectionName: String?
    private var engine: SpeedTestEngine?
    private var engineFactory: @MainActor () -> SpeedTestEngine

    private static let historyDefaultsKey = "speedTestHistory"
    private static let historyLimit = 50

    var isTesting: Bool { isRunning }

    init(engineFactory: @escaping @MainActor () -> SpeedTestEngine = { SpeedTestEngine() }) {
        self.engineFactory = engineFactory
        loadHistory()
    }

    // MARK: - History persistence + rename

    func renameResult(_ id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let idx = history.firstIndex(where: { $0.id == id }) else { return }
        history[idx].name = trimmed.isEmpty ? nil : trimmed
        saveHistory()
    }

    func deleteResult(_ id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.historyDefaultsKey),
              let decoded = try? JSONDecoder().decode([SpeedTestResult].self, from: data) else { return }
        history = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyDefaultsKey)
    }

    // MARK: - Lifecycle

    func start(connectionName: String? = nil) {
        guard !isRunning else { return }
        isRunning = true
        error = nil
        progress = 0
        pendingConnectionName = connectionName
        resetLive()
        
        let newEngine = engineFactory()
        newEngine.delegate = self
        self.engine = newEngine
        
        Task { await runTest() }
    }

    func cancel() {
        engine?.cancel()
        isRunning = false
        phase = .idle
    }

    private func resetLive() {
        downloadMbps = 0; uploadMbps = 0; pingMs = 0; jitterMs = 0
        browsingAvgMs = 0; browsingMedianTtfb = 0; browsingProcessed = 0
        gameMedianMs = 0; gameP99Ms = 0; gameJitterMs = 0; gameLossPct = 0
        streamAvgMbps = 0; streamMinMbps = 0; streamTier = "—"
    }

    private func runTest() async {
        guard let currentEngine = engine else { return }
        do {
            let result = try await currentEngine.runTest(kind: kind)
            phase = .done
            progress = 1.0
            recordResult(result)
        } catch {
            self.error = (error as NSError).localizedDescription
            phase = .failed
        }
        isRunning = false
        engine = nil
    }

    private func recordResult(_ result: SpeedTestResult) {
        var stamped = result
        if stamped.name == nil || stamped.name?.isEmpty == true {
            stamped.name = pendingConnectionName
        }
        lastResult = stamped
        history.insert(stamped, at: 0)
        if history.count > Self.historyLimit { history.removeLast() }
        saveHistory()
        pendingConnectionName = nil
    }
}
