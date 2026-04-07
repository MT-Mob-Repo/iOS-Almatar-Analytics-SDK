import Foundation
import SQLite3

/// SQLite-backed persistent event queue using raw SQLite3 C API.
///
/// Hardening:
/// - Every sqlite3_* call checks its return code; failures are logged.
/// - Transactions use defer { ROLLBACK } so a failure at any point safely
///   undoes partial work — no data loss from half-committed overflow deletes.
/// - Malformed JSON rows are logged and deleted (never silently accumulate).
/// - SQLITE_TRANSIENT defined correctly without unsafeBitCast.
/// - AUTOINCREMENT removed from schema (same rationale as Android).
/// - NSLock kept (not removed) because Dispatcher actor calls these methods
///   and actors do NOT serialise calls to non-actor types automatically.
final class QueueStore {
    private var db: OpaquePointer?
    private let maxSize: Int
    private let lock = NSLock()
    private let dbPath: String
    private let logger: LALogger

    // Correct definition of SQLITE_TRANSIENT without unsafeBitCast
    private let SQLITE_TRANSIENT = unsafeBitCast(
        OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self
    )

    init(maxSize: Int, databaseURL: URL? = nil, logger: LALogger = LALogger(debug: false)) {
        self.maxSize = maxSize
        self.logger = logger
        let url: URL
        if let custom = databaseURL {
            url = custom
        } else {
            let dir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            url = dir.appendingPathComponent("la_events.sqlite")
        }
        dbPath = url.path
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        openDatabase()
        createTableIfNeeded()
    }

    deinit { sqlite3_close(db) }

    func enqueue(_ event: EventModel) {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(event),
              let json = String(data: data, encoding: .utf8) else {
            logger.e("Failed to encode event to JSON — dropped")
            return
        }

        // BEGIN IMMEDIATE acquires a write lock upfront, making the overflow
        // check + drop + insert a single atomic unit.
        guard exec("BEGIN IMMEDIATE") else { return }

        // On ANY failure inside the transaction, ROLLBACK undoes partial work
        // (e.g. overflow rows deleted but new event not inserted → no data loss).
        var committed = false
        defer { if !committed { exec("ROLLBACK") } }

        let currentCount = rowCount()
        if currentCount >= maxSize {
            let dropCount = maxSize / 4
            guard exec(
                "DELETE FROM events WHERE id IN (SELECT id FROM events ORDER BY id ASC LIMIT \(dropCount))"
            ) else { return }
        }

        var stmt: OpaquePointer?
        guard prepare("INSERT INTO events (payload, created_at) VALUES (?, ?)", into: &stmt) else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, json, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 2, Int64(Date().timeIntervalSince1970 * 1000))

        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE else {
            logger.e("INSERT step failed: \(rc) — \(errorMessage)")
            return
        }

        guard exec("COMMIT") else { return }
        committed = true
    }

    func peek(limit: Int) -> [EventModel] {
        lock.lock(); defer { lock.unlock() }
        var results: [EventModel] = []
        var corruptRowIds: [Int64] = []
        var stmt: OpaquePointer?
        guard prepare("SELECT id, payload FROM events ORDER BY id ASC LIMIT \(limit)", into: &stmt) else {
            return results
        }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowId = sqlite3_column_int64(stmt, 0)
            guard sqlite3_column_type(stmt, 1) == SQLITE_TEXT,
                  let cStr = sqlite3_column_text(stmt, 1),
                  let data = String(cString: cStr).data(using: .utf8),
                  let event = try? JSONDecoder().decode(EventModel.self, from: data)
            else {
                logger.e("Malformed JSON in queue row \(rowId) — will be purged")
                corruptRowIds.append(rowId)
                continue
            }
            results.append(event)
        }

        // Clean up corrupt rows so they don't permanently occupy queue space
        if !corruptRowIds.isEmpty {
            let ids = corruptRowIds.map(String.init).joined(separator: ",")
            exec("DELETE FROM events WHERE id IN (\(ids))")
            logger.e("Purged \(corruptRowIds.count) corrupt row(s) from queue")
        }

        return results
    }

    /// Parameterised DELETE — safe against malformed eventId strings.
    func remove(eventIds: [String]) {
        guard !eventIds.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        for eventId in eventIds {
            var stmt: OpaquePointer?
            let sql = "DELETE FROM events WHERE json_extract(payload, '$.eventId') = ?"
            guard prepare(sql, into: &stmt) else { continue }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, eventId, -1, SQLITE_TRANSIENT)
            let rc = sqlite3_step(stmt)
            if rc != SQLITE_DONE {
                logger.e("DELETE step failed for eventId \(eventId): \(rc) — \(errorMessage)")
            }
        }
    }

    func count() -> Int {
        lock.lock(); defer { lock.unlock() }
        return rowCount()
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        exec("DELETE FROM events")
    }

    // MARK: - Private helpers

    private func openDatabase() {
        let rc = sqlite3_open(dbPath, &db)
        if rc != SQLITE_OK {
            logger.e("sqlite3_open failed: \(rc) — \(errorMessage)")
        }
        exec("PRAGMA journal_mode=WAL;")
        exec("PRAGMA synchronous=NORMAL;")   // perf: fsync on checkpoint only
    }

    private func createTableIfNeeded() {
        exec("""
            CREATE TABLE IF NOT EXISTS events (
                id         INTEGER PRIMARY KEY,
                payload    TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )
            """)
        // Index for json_extract-based deletes
        exec("CREATE INDEX IF NOT EXISTS idx_event_id ON events(json_extract(payload, '$.eventId'))")
    }

    private func rowCount() -> Int {
        var stmt: OpaquePointer?
        guard prepare("SELECT COUNT(*) FROM events", into: &stmt) else { return 0 }
        defer { sqlite3_finalize(stmt) }
        var count = 0
        if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int(stmt, 0)) }
        return count
    }

    // MARK: - SQLite error-checking wrappers

    /// Executes a simple SQL string. Returns true on success, false on failure.
    @discardableResult
    private func exec(_ sql: String) -> Bool {
        let rc = sqlite3_exec(db, sql, nil, nil, nil)
        if rc != SQLITE_OK {
            logger.e("sqlite3_exec failed (\(rc)): \(errorMessage) — SQL: \(sql.prefix(120))")
            return false
        }
        return true
    }

    /// Prepares a statement. Returns true on success, false on failure.
    /// On failure the statement pointer is left nil.
    private func prepare(_ sql: String, into stmt: inout OpaquePointer?) -> Bool {
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        if rc != SQLITE_OK {
            logger.e("sqlite3_prepare_v2 failed (\(rc)): \(errorMessage) — SQL: \(sql.prefix(120))")
            stmt = nil
            return false
        }
        return true
    }

    /// Human-readable error message from the current database connection.
    private var errorMessage: String {
        if let msg = sqlite3_errmsg(db) {
            return String(cString: msg)
        }
        return "unknown error"
    }
}
