import XCTest
@testable import LightAnalytics

// MockTransport conforms to TransportProtocol (now defined in Dispatcher.swift)
final class MockTransport: TransportProtocol, @unchecked Sendable {
    private let handler: ([EventModel]) async -> TransportResult
    init(handler: @escaping ([EventModel]) async -> TransportResult) {
        self.handler = handler
    }
    func sendBatch(_ events: [EventModel]) async -> TransportResult { await handler(events) }
}

// MARK: - Tests

final class AnalyticsTests: XCTestCase {

    private var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        testDefaults = UserDefaults(suiteName: "la_test_\(UUID().uuidString)")!
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        try await super.tearDown()
    }

    // MARK: - EventBuilder

    func testEventHasUniqueEventId() {
        let b = makeBuilder()
        XCTAssertNotEqual(b.build(name:"e1",properties:[:]).eventId,
                          b.build(name:"e2",properties:[:]).eventId)
    }

    func testEventTimestampIsUTC() {
        XCTAssertTrue(makeBuilder().build(name:"t",properties:[:]).timestamp.hasSuffix("Z"))
    }

    func testAnonymousIdPresentWhenNoUser() {
        let e = makeBuilder().build(name:"t",properties:[:])
        XCTAssertNil(e.userId)
        XCTAssertFalse(e.anonymousId.isEmpty)
    }

    func testUserIdAfterIdentify() {
        let store = IdentityStore(defaults: testDefaults)
        store.userId = "u-99"
        let e = makeBuilder(identityStore: store).build(name:"t",properties:[:])
        XCTAssertEqual(e.userId, "u-99")
    }

    // MARK: - Super properties (async — actor methods require await)

    func testSuperPropertiesMergedIntoEvent() async {
        let store = SuperPropertiesStore(defaults: testDefaults)
        await store.register(["env": "prod", "section": "consumer"])
        let e = makeBuilder(superStore: store).build(name:"t",properties:[:])
        XCTAssertEqual(e.properties["env"]?.value as? String, "prod")
    }

    func testEventPropertiesWinOnConflict() async {
        let store = SuperPropertiesStore(defaults: testDefaults)
        await store.register(["version": "old"])
        let e = makeBuilder(superStore: store).build(name:"t",properties:["version":"new"])
        XCTAssertEqual(e.properties["version"]?.value as? String, "new")
    }

    func testUnregisterRemovesOneKey() async {
        let store = SuperPropertiesStore(defaults: testDefaults)
        await store.register(["a":"1","b":"2"])
        await store.unregister("a")
        let all = await store.getAll()
        XCTAssertNil(all["a"])
        XCTAssertEqual(all["b"] as? String, "2")
    }

    func testClearRemovesAllSuperProperties() async {
        let store = SuperPropertiesStore(defaults: testDefaults)
        await store.register(["x":"1"])
        await store.clear()
        let all = await store.getAll()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - AnyCodable type preservation

    func testAnyCodableBoolSurvivesJsonRoundTrip() throws {
        // Bool(true) must NOT become Int(1) after encode → decode
        let original: [String: AnyCodable] = [
            "flag_true":  AnyCodable(true),
            "flag_false": AnyCodable(false),
            "count":      AnyCodable(42),
            "ratio":      AnyCodable(3.14),
            "label":      AnyCodable("hello"),
        ]
        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: data)

        // Booleans must round-trip as Bool, not Int
        XCTAssertTrue(decoded["flag_true"]!.value is Bool,  "true should decode as Bool, got \(type(of: decoded["flag_true"]!.value))")
        XCTAssertTrue(decoded["flag_false"]!.value is Bool, "false should decode as Bool, got \(type(of: decoded["flag_false"]!.value))")
        XCTAssertEqual(decoded["flag_true"]!.value  as? Bool, true)
        XCTAssertEqual(decoded["flag_false"]!.value as? Bool, false)

        // Int, Double, String must also survive
        XCTAssertTrue(decoded["count"]!.value is Int)
        XCTAssertEqual(decoded["count"]!.value as? Int, 42)
        XCTAssertTrue(decoded["ratio"]!.value is Double)
        XCTAssertEqual(decoded["ratio"]!.value as? Double, 3.14)
        XCTAssertTrue(decoded["label"]!.value is String)
        XCTAssertEqual(decoded["label"]!.value as? String, "hello")
    }

    func testSuperPropertiesPreserveBoolAfterReload() async {
        // Simulates what happens when the app restarts: values go through persist → load
        let suite = "la_anyCodable_test_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let store = SuperPropertiesStore(defaults: defaults)
        await store.register(["is_premium": true, "count": 5, "name": "test"])

        // Create a fresh store from the same UserDefaults — forces a reload from disk
        let reloaded = SuperPropertiesStore(defaults: defaults)
        let snapshot = reloaded.snapshot()

        XCTAssertTrue(snapshot["is_premium"] is Bool, "Bool must survive reload, got \(type(of: snapshot["is_premium"]!))")
        XCTAssertEqual(snapshot["is_premium"] as? Bool, true)
        XCTAssertEqual(snapshot["count"]      as? Int, 5)
        XCTAssertEqual(snapshot["name"]       as? String, "test")
    }

    // MARK: - Retry policy

    func testRetryAllowedUpToMaxAttempts() {
        let p = RetryPolicy(maxAttempts: 3)
        XCTAssertTrue(p.shouldRetry(attempt: 0))
        XCTAssertTrue(p.shouldRetry(attempt: 2))
        XCTAssertFalse(p.shouldRetry(attempt: 3))
    }

    func testRetryDelayExponentialAndCapped() {
        let p = RetryPolicy(maxAttempts: 5, baseDelay: 1, maxDelay: 16)
        XCTAssertEqual(p.delay(attempt: 0), 2)
        XCTAssertEqual(p.delay(attempt: 2), 8)
        XCTAssertEqual(p.delay(attempt: 4), 16)
    }

    // MARK: - Identity

    func testResetClearsUserId() {
        let store = IdentityStore(defaults: testDefaults)
        store.userId = "u-1"; store.reset()
        XCTAssertNil(store.userId)
    }

    func testResetRegeneratesAnonymousId() {
        let store = IdentityStore(defaults: testDefaults)
        let before = store.anonymousId; store.reset()
        XCTAssertNotEqual(before, store.anonymousId)
    }

    // MARK: - Session

    func testSessionStableWithinTimeout() {
        let sm = SessionManager(defaults: testDefaults, timeoutSeconds: 1800)
        XCTAssertEqual(sm.sessionId(), sm.sessionId())
    }

    func testSessionResetChangesId() {
        let sm = SessionManager(defaults: testDefaults, timeoutSeconds: 1800)
        let before = sm.sessionId(); sm.reset()
        XCTAssertNotEqual(before, sm.sessionId())
    }

    // MARK: - Queue

    func testQueueSurvivesReinit() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("la_test_\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let q1 = QueueStore(maxSize: 100, databaseURL: url)
        q1.enqueue(makeBuilder().build(name:"persisted", properties:[:]))
        let q2 = QueueStore(maxSize: 100, databaseURL: url)
        XCTAssertEqual(q2.peek(limit:10).first?.name, "persisted")
    }

    func testQueueRemoveDeletesCorrectEvent() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("la_test_\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let q = QueueStore(maxSize: 100, databaseURL: url)
        let e1 = makeBuilder().build(name:"one",properties:[:])
        let e2 = makeBuilder().build(name:"two",properties:[:])
        q.enqueue(e1); q.enqueue(e2)
        q.remove(eventIds: [e1.eventId])
        XCTAssertEqual(q.peek(limit:10).first?.name, "two")
    }

    func testQueueOverflowDropsOldest() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("la_test_\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let q = QueueStore(maxSize: 8, databaseURL: url)
        (0..<8).forEach { q.enqueue(makeBuilder().build(name:"e\($0)",properties:[:])) }
        q.enqueue(makeBuilder().build(name:"new",properties:[:]))
        // After overflow: dropped 2 oldest (25% of 8), then inserted 1 → 7 total
        XCTAssertEqual(q.count(), 7)
        let names = q.peek(limit:10).map { $0.name }
        XCTAssertFalse(names.contains("e0"))
        XCTAssertTrue(names.contains("new"))
    }

    // MARK: - Dispatcher

    func testDispatcherFlushesOnBatchSize() async {
        let q = QueueStore(maxSize: 100)
        var sent = 0
        let transport = MockTransport { batch in sent += batch.count; return .success }
        let d = Dispatcher(
            queue: q, transport: transport, retryPolicy: RetryPolicy(),
            logger: LALogger(debug: false), batchSize: 2, flushInterval: 60
        )
        let b = makeBuilder()
        await d.enqueue(b.build(name:"a",properties:[:]))
        await d.enqueue(b.build(name:"b",properties:[:]))
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(q.count(), 0)
    }

    func testDispatcherRetryThenSuccess() async {
        let q = QueueStore(maxSize: 100)
        var calls = 0
        let transport = MockTransport { _ in
            calls += 1
            return calls == 1 ? .retryable("503") : .success
        }
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0.01, maxDelay: 0.1)
        let d = Dispatcher(
            queue: q, transport: transport, retryPolicy: policy,
            logger: LALogger(debug: false), batchSize: 10, flushInterval: 60
        )
        await d.enqueue(makeBuilder().build(name:"retry",properties:[:]))
        await d.flush()
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(q.count(), 0)
    }

    func testBlankEventNameIsDropped() async {
        let q = QueueStore(maxSize: 100)
        let d = Dispatcher(
            queue: q, transport: MockTransport { _ in .success },
            retryPolicy: RetryPolicy(), logger: LALogger(debug: false),
            batchSize: 10, flushInterval: 60
        )
        // Blank name should be dropped by Dispatcher
        await d.enqueue(EventModel(
            eventId: UUID().uuidString, name: "   ",
            timestamp: "2026-01-01T00:00:00Z",
            userId: nil, anonymousId: "anon", sessionId: "sess",
            context: EventContext(sdkName:"s",sdkVersion:"1",platform:"ios",
                appVersion:"1",buildNumber:"1",deviceModel:"D",
                osVersion:"17",locale:"en",timezone:"UTC"),
            properties: [:]
        ))
        XCTAssertEqual(q.count(), 0)
    }

    // MARK: - Helpers

    private func makeBuilder(
        identityStore: IdentityStore? = nil,
        superStore: SuperPropertiesStore? = nil
    ) -> EventBuilder {
        EventBuilder(
            contextProvider: ContextProvider(),
            identityStore: identityStore ?? IdentityStore(defaults: testDefaults),
            sessionManager: SessionManager(defaults: testDefaults, timeoutSeconds: 1800),
            superPropertiesStore: superStore ?? SuperPropertiesStore(defaults: testDefaults)
        )
    }
}
