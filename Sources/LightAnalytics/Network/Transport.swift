import Foundation

enum TransportResult: Sendable {
    case success
    case retryable(String)
    case fatal(String)
}

/// HTTP transport backed by URLSession async/await.
///
/// When `debug` is true, every request URL, headers, body and the response
/// status + body are printed to the Xcode console via `print()`.
///
/// `print()` is used rather than `os.log Logger.debug()` because `.debug`-level
/// unified-log messages are NOT forwarded to the Xcode console on real devices.
/// Zero overhead when `debug = false`.
final class Transport: Sendable {
    private let baseUrl: URL
    private let additionalHeaders: [String: String]
    private let session: URLSession
    private let debug: Bool
    private let tag = "[LightAnalytics][HTTP]"

    init(
        baseUrl: URL,
        additionalHeaders: [String: String] = [:],
        timeoutSeconds: TimeInterval = 10,
        debug: Bool = false
    ) {
        self.baseUrl           = baseUrl
        self.additionalHeaders = additionalHeaders
        self.debug             = debug

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds * 3
        config.httpShouldSetCookies       = false
        config.httpCookieAcceptPolicy     = .never
        self.session = URLSession(configuration: config)
    }

    func sendBatch(_ events: [EventModel]) async -> TransportResult {
        var request = URLRequest(url: baseUrl)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        additionalHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let payload: [String: Any] = ["batch": events.map { $0.toDictionary() }]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return .fatal("Payload serialisation failed")
        }
        request.httpBody = body

        if debug { logRequest(request, body: body) }

        do {
            let start = Date()
            let (data, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(start)

            guard let http = response as? HTTPURLResponse else {
                return .retryable("Non-HTTP response")
            }

            if debug { logResponse(http, data: data, elapsed: elapsed) }

            switch http.statusCode {
            case 200...299:      return .success
            case 429, 500...599: return .retryable("HTTP \(http.statusCode)")
            default:             return .fatal("HTTP \(http.statusCode) – will not retry")
            }
        } catch {
            if debug {
                print("\(tag) ❌ Network failure: \(error.localizedDescription)")
            }
            return .retryable(error.localizedDescription)
        }
    }

    // MARK: - Debug logging

    private func logRequest(_ request: URLRequest, body: Data) {
        let bodyStr = String(data: body, encoding: .utf8) ?? "<binary>"
        print("""
            \(tag) ➡️  --> \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")
            Headers: \(request.allHTTPHeaderFields?.description ?? "{}")
            Body: \(bodyStr)
            """)
    }

    private func logResponse(_ response: HTTPURLResponse, data: Data, elapsed: TimeInterval) {
        let bodyStr = String(data: data, encoding: .utf8) ?? "<binary>"
        let ms = Int(elapsed * 1000)
        print("""
            \(tag) ⬅️  <-- \(response.statusCode) (\(ms)ms)
            Body: \(bodyStr)
            """)
    }
}
