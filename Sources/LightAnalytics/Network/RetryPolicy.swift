import Foundation

/// Exponential backoff retry policy with ±20 % jitter.
///
/// Base delays: 2 s → 4 s → 8 s → 16 s → 32 s (capped at maxDelay).
/// Jitter spreads each retry across [base * 0.8, base * 1.2] to prevent
/// thundering-herd storms when many devices retry after a shared outage.
struct RetryPolicy {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval

    init(maxAttempts: Int = 5, baseDelay: TimeInterval = 2, maxDelay: TimeInterval = 32) {
        self.maxAttempts = maxAttempts
        self.baseDelay   = baseDelay
        self.maxDelay    = maxDelay
    }

    func shouldRetry(attempt: Int) -> Bool { attempt < maxAttempts }

    func delay(attempt: Int) -> TimeInterval {
        let exp  = min(attempt, 5)
        let base = min(baseDelay * pow(2.0, Double(exp)), maxDelay)
        // ±20 % jitter: multiply by a random factor in [0.8, 1.2]
        let jitter = 0.8 + Double.random(in: 0..<0.4)
        return base * jitter
    }
}
