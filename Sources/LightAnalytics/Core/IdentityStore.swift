import Foundation

/// Stores userId and anonymousId in UserDefaults.
/// anonymousId is generated once and kept until reset().
final class IdentityStore {
    private let defaults: UserDefaults
    private let keyAnonymousId = "la_anonymous_id"
    private let keyUserId      = "la_user_id"

    /// Guards the check-then-set window during first anonymousId generation.
    /// Fast path (ID already exists) never acquires the lock.
    private let anonIdLock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var anonymousId: String {
        // Fast path — no lock required; UserDefaults reads are atomic on Apple platforms.
        if let existing = defaults.string(forKey: keyAnonymousId) { return existing }

        // Slow path — lock prevents two racing threads from both generating a UUID
        // and persisting different values (TOCTOU race on first launch).
        anonIdLock.lock(); defer { anonIdLock.unlock() }

        // Re-check inside the lock: another thread may have written it
        // between the fast-path read above and acquiring the lock.
        if let existing = defaults.string(forKey: keyAnonymousId) { return existing }

        let newId = UUID().uuidString
        defaults.set(newId, forKey: keyAnonymousId)
        return newId
    }

    var userId: String? {
        get { defaults.string(forKey: keyUserId) }
        set {
            // Skip the disk write when the value hasn't changed.
            guard newValue != defaults.string(forKey: keyUserId) else { return }
            if let value = newValue {
                defaults.set(value, forKey: keyUserId)
            } else {
                defaults.removeObject(forKey: keyUserId)
            }
        }
    }

    func reset() {
        defaults.removeObject(forKey: keyUserId)
        defaults.removeObject(forKey: keyAnonymousId)
    }
}
