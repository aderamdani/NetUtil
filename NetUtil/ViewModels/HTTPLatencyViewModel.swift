import Foundation
import Combine
import Observation

private final class MetricsDelegate: NSObject, URLSessionTaskDelegate {
    var metrics: URLSessionTaskMetrics?
    var followRedirects = true

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        self.metrics = metrics
    }

    // Returning nil for newRequest halts the redirect and surfaces the 3xx
    // response itself — the only correct way to honor "Follow Redirects = off".
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(followRedirects ? request : nil)
    }
}

@Observable
@MainActor
final class HTTPLatencyViewModel {
    var result: HTTPLatencyResult?
    var history: [HTTPLatencyResult] = []
    var isRunning = false
    var error: String?

    private var currentTask: Task<Void, Never>?

    func run(urlString: String, method: String, followRedirects: Bool) {
        cancel()
        error = nil
        result = nil
        isRunning = true

        currentTask = Task {
            do {
                let r = try await Self.fetch(urlString: urlString,
                                             method: method,
                                             followRedirects: followRedirects)
                result = r
                history.insert(r, at: 0)
                if history.count > 20 { history.removeLast() }
            } catch is CancellationError {
            } catch {
                self.error = error.localizedDescription
            }
            isRunning = false
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
    }

    private static func fetch(urlString: String,
                               method: String,
                               followRedirects: Bool) async throws -> HTTPLatencyResult {
        guard var urlStr = Optional(urlString.trimmingCharacters(in: .whitespaces)),
              !urlStr.isEmpty else {
            throw URLError(.badURL)
        }
        if !urlStr.lowercased().hasPrefix("http") { urlStr = "https://" + urlStr }
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        let delegate = MetricsDelegate()
        delegate.followRedirects = followRedirects
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("NetUtil/1.0", forHTTPHeaderField: "User-Agent")

        let start = Date()
        let (data, response) = try await session.data(for: req)
        let totalMs = Date().timeIntervalSince(start) * 1000

        let statusCode = (response as? HTTPURLResponse)?.statusCode
        let bodyBytes = Int64(data.count)

        var phases: [HTTPPhaseTiming] = []

        if let metrics = delegate.metrics,
           let tx = metrics.transactionMetrics.last {
            let origin = tx.fetchStartDate ?? start

            func ms(_ from: Date?, _ to: Date?) -> Double? {
                guard let f = from, let t = to, t > f else { return nil }
                return t.timeIntervalSince(f) * 1000
            }
            func offset(_ d: Date?) -> Double {
                guard let d else { return 0 }
                return max(0, d.timeIntervalSince(origin) * 1000)
            }

            if let dur = ms(tx.domainLookupStartDate, tx.domainLookupEndDate) {
                phases.append(HTTPPhaseTiming(phase: .dns,
                                              startMs: offset(tx.domainLookupStartDate),
                                              durationMs: dur))
            }
            let tcpStart = tx.connectStartDate
            let tcpEnd = tx.secureConnectionStartDate ?? tx.connectEndDate
            if let dur = ms(tcpStart, tcpEnd) {
                phases.append(HTTPPhaseTiming(phase: .tcp,
                                              startMs: offset(tcpStart),
                                              durationMs: dur))
            }
            if let dur = ms(tx.secureConnectionStartDate, tx.secureConnectionEndDate) {
                phases.append(HTTPPhaseTiming(phase: .tls,
                                              startMs: offset(tx.secureConnectionStartDate),
                                              durationMs: dur))
            }
            if let dur = ms(tx.requestStartDate, tx.requestEndDate) {
                phases.append(HTTPPhaseTiming(phase: .request,
                                              startMs: offset(tx.requestStartDate),
                                              durationMs: dur))
            }
            if let dur = ms(tx.requestEndDate, tx.responseStartDate) {
                phases.append(HTTPPhaseTiming(phase: .ttfb,
                                              startMs: offset(tx.requestEndDate),
                                              durationMs: dur))
            }
            if let dur = ms(tx.responseStartDate, tx.responseEndDate) {
                phases.append(HTTPPhaseTiming(phase: .download,
                                              startMs: offset(tx.responseStartDate),
                                              durationMs: dur))
            }
        }

        return HTTPLatencyResult(
            url: url.absoluteString,
            method: method,
            statusCode: statusCode,
            totalMs: totalMs,
            phases: phases,
            bodyBytes: bodyBytes,
            redirectCount: delegate.metrics?.redirectCount ?? 0,
            timestamp: start
        )
    }
}
