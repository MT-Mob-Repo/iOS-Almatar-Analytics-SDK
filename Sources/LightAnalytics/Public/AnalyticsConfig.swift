import Foundation

/// Configuration for the LightAnalytics SDK.
///
/// Two URLs are required — one for debug and one for production:
///
/// ```swift
/// Analytics.initialize(
///     config: AnalyticsConfig(
///         debugUrl:      "https://alpha.example.com/events/batch",
///         productionUrl: "https://api.example.com/events/batch",
///         debug: true   // uses debugUrl; false uses productionUrl
///     )
/// )
/// ```
///
/// Rules:
/// - `productionUrl` **must** use HTTPS (enforced at init time).
/// - `debugUrl` may use HTTP or HTTPS (useful for local / staging servers).
/// - When `debug = true` the SDK routes to `debugUrl`; otherwise to `productionUrl`.
public struct AnalyticsConfig: Sendable {
    public let debugUrl: URL
    public let productionUrl: URL
    public let flushBatchSize: Int
    public let flushIntervalSeconds: TimeInterval
    public let maxQueueSize: Int
    public let sessionTimeoutSeconds: TimeInterval
    public let debug: Bool
    public let additionalHeaders: [String: String]

    /// The URL the SDK will send events to.
    /// Returns `debugUrl` when `debug` is `true`, `productionUrl` otherwise.
    public var activeUrl: URL { debug ? debugUrl : productionUrl }

    public init(
        debugUrl: String,
        productionUrl: String,
        flushBatchSize: Int = 20,
        flushIntervalSeconds: TimeInterval = 30,
        maxQueueSize: Int = 1000,
        sessionTimeoutSeconds: TimeInterval = 1800,
        debug: Bool = false,
        additionalHeaders: [String: String] = [:]
    ) {
        guard let debugParsed = URL(string: debugUrl), debugParsed.scheme != nil else {
            preconditionFailure("debugUrl is not a valid URL: \(debugUrl)")
        }
        guard let prodParsed = URL(string: productionUrl), prodParsed.scheme != nil else {
            preconditionFailure("productionUrl is not a valid URL: \(productionUrl)")
        }
        precondition(
            prodParsed.scheme == "https",
            "productionUrl must use HTTPS. Got: \"\(prodParsed.scheme ?? "nil")\""
        )
        precondition(flushBatchSize > 0 && flushBatchSize <= 500, "flushBatchSize must be 1–500")
        precondition(maxQueueSize >= flushBatchSize, "maxQueueSize must be >= flushBatchSize")

        self.debugUrl             = debugParsed
        self.productionUrl        = prodParsed
        self.flushBatchSize       = flushBatchSize
        self.flushIntervalSeconds = flushIntervalSeconds
        self.maxQueueSize         = maxQueueSize
        self.sessionTimeoutSeconds = sessionTimeoutSeconds
        self.debug                = debug
        self.additionalHeaders    = additionalHeaders
    }
}
