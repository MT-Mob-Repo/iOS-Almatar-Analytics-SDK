import Foundation

/**
 * Actor-backed super properties store with an in-memory cache.
 *
 * Type preservation:
 *   Persists values using JSONEncoder with [String: AnyCodable].
 *   AnyCodable decodes Bool BEFORE Int, so a stored Bool(true) always
 *   reloads as Bool(true) — never as NSNumber(1) or Int(1).
 *   JSONSerialization was removed because it loses Bool type information
 *   on reload (true/false become NSNumber, indistinguishable from 0/1).
 *
 * Thread model:
 *   _snapshot is nonisolated(unsafe) — written only under actor isolation,
 *   read by EventBuilder.build() on whichever thread calls track().
 *   Safe because ARC reference replacement is atomic and EventBuilder only
 *   needs a best-effort snapshot at build time.
 */
actor SuperPropertiesStore {
    private let defaults: UserDefaults
    private let key = "la_super_properties"

    nonisolated(unsafe) private var _snapshot: [String: Any] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        _snapshot = Self.load(from: defaults, key: "la_super_properties")
    }

    // MARK: - Actor-isolated writes

    func register(_ properties: [String: Any]) {
        var next = _snapshot
        properties.forEach { next[$0] = $1 }
        _snapshot = next
        persist(next)
    }

    func unregister(_ key: String) {
        guard _snapshot[key] != nil else { return }
        var next = _snapshot
        next.removeValue(forKey: key)
        _snapshot = next
        persist(next)
    }

    func clear() {
        _snapshot = [:]
        defaults.removeObject(forKey: key)
    }

    func getAll() -> [String: Any] { _snapshot }

    /// Synchronous snapshot for use from EventBuilder.build() without an actor hop.
    nonisolated func snapshot() -> [String: Any] { _snapshot }

    /// Synchronous clear for use from reset().
    ///
    /// Why this exists: `clear()` is actor-isolated and requires `await`.
    /// `AnalyticsCore.reset()` dispatches it in a fire-and-forget `Task`,
    /// but `track()` called immediately after `reset()` reads `snapshot()`
    /// *before* the actor task executes — leaking old super properties
    /// (email, tier, etc.) into the guest's first event.
    ///
    /// `clearSync()` writes `_snapshot = [:]` on the caller's thread so
    /// the very next `snapshot()` read returns empty.
    /// `defaults` and `key` are both `let` — safe to access from nonisolated.
    nonisolated func clearSync() {
        _snapshot = [:]
        defaults.removeObject(forKey: key)
    }

    // MARK: - Private persistence

    /// Encodes the dictionary as [String: AnyCodable] so Bool, Int, Double, and String
    /// all survive the JSON round-trip with their original Swift types.
    private func persist(_ dict: [String: Any]) {
        let codable = dict.mapValues { AnyCodable($0) }
        guard let data = try? JSONEncoder().encode(codable) else { return }
        defaults.set(data, forKey: key)
    }

    /// Decodes using JSONDecoder + AnyCodable, which tries Bool before Int.
    /// This guarantees Bool(true) reloads as Bool — not as NSNumber or Int.
    private static func load(from defaults: UserDefaults, key: String) -> [String: Any] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: AnyCodable].self, from: data)
        else { return [:] }
        return decoded.mapValues { $0.value }
    }
}
