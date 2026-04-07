import Foundation

/// V1 Session strategy: fresh session on cold start; renewed after inactivity timeout.
/// sessionId is NOT persisted across cold starts. lastActiveDate IS persisted so
/// hot-resume inactivity checks work correctly.
final class SessionManager {
    private let defaults: UserDefaults
    private let timeoutSeconds: TimeInterval

    private let keySessionId  = "la_session_id"
    private let keyLastActive = "la_last_active"

    private var _sessionId: String

    init(defaults: UserDefaults = .standard, timeoutSeconds: TimeInterval) {
        self.defaults = defaults
        self.timeoutSeconds = timeoutSeconds

        // Determine if the hot-resumed session is still valid
        if let lastActive = defaults.object(forKey: "la_last_active") as? Date,
           Date().timeIntervalSince(lastActive) < timeoutSeconds,
           let saved = defaults.string(forKey: "la_session_id") {
            _sessionId = saved
        } else {
            _sessionId = UUID().uuidString
        }
        touch()
    }

    private let lock = NSLock()

    func sessionId() -> String {
        lock.lock(); defer { lock.unlock() }
        if let lastActive = defaults.object(forKey: keyLastActive) as? Date,
           Date().timeIntervalSince(lastActive) >= timeoutSeconds {
            _sessionId = UUID().uuidString
        }
        touch()
        return _sessionId
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        _sessionId = UUID().uuidString
        touch()
    }

    private func touch() {
        defaults.set(_sessionId, forKey: keySessionId)
        defaults.set(Date(), forKey: keyLastActive)
    }
}
