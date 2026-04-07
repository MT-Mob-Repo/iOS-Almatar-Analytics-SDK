import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class Analytics {

    private static var _instance: AnalyticsCore?
    private static let initLock = NSLock()

    public static func initialize(config: AnalyticsConfig) {
        initLock.lock(); defer { initLock.unlock() }
        guard _instance == nil else { return }
        _instance = AnalyticsCore(config: config)
    }

    public static func track(_ event: String, properties: [String: Any] = [:]) {
        instance.track(event, properties: properties)
    }
    public static func identify(_ userId: String)    { instance.identify(userId) }
    public static func reset()                        { instance.reset() }
    public static func flush()                        { instance.flush() }

    public static func registerSuperProperties(_ properties: [String: Any]) {
        instance.registerSuperProperties(properties)
    }
    public static func unregisterSuperProperty(_ key: String) {
        instance.unregisterSuperProperty(key)
    }
    public static func clearSuperProperties()         { instance.clearSuperProperties() }

    public static func trackScreen(_ name: String, properties: [String: Any] = [:]) {
        instance.trackScreen(name, properties: properties)
    }
    public static func setGroup(_ key: String, id: Any) { instance.setGroup(key, id: id) }

    private static var instance: AnalyticsCore {
        guard let i = _instance else {
            fatalError("Analytics not initialised. Call Analytics.initialize(config:) first.")
        }
        return i
    }
}

// MARK: - AnalyticsCore

final class AnalyticsCore {
    private let logger: LALogger
    private let identityStore: IdentityStore
    private let sessionManager: SessionManager
    private let superPropertiesStore: SuperPropertiesStore
    private let eventBuilder: EventBuilder
    private let dispatcher: Dispatcher
    private let debugMode: Bool

    #if canImport(UIKit)
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    #endif

    init(config: AnalyticsConfig) {
        self.debugMode = config.debug
        logger = LALogger(debug: config.debug)
        let defaults = UserDefaults.standard
        identityStore        = IdentityStore(defaults: defaults)
        sessionManager       = SessionManager(defaults: defaults, timeoutSeconds: config.sessionTimeoutSeconds)
        superPropertiesStore = SuperPropertiesStore(defaults: defaults)

        eventBuilder = EventBuilder(
            contextProvider:     ContextProvider(),
            identityStore:       identityStore,
            sessionManager:      sessionManager,
            superPropertiesStore: superPropertiesStore
        )

        let transport = Transport(
            baseUrl:           config.activeUrl,
            additionalHeaders: config.additionalHeaders,
            debug:             config.debug
        )
        dispatcher = Dispatcher(
            queue:         QueueStore(maxSize: config.maxQueueSize, logger: logger),
            transport:     transport,
            retryPolicy:   RetryPolicy(),
            logger:        logger,
            batchSize:     config.flushBatchSize,
            flushInterval: config.flushIntervalSeconds
        )
        registerBackgroundNotification()
    }

    deinit {
        // Cancel Dispatcher timer/flush tasks to prevent leaked coroutines
        Task { [dispatcher] in await dispatcher.shutdown() }
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self)
        #endif
    }

    func track(_ event: String, properties: [String: Any]) {
        guard !event.trimmingCharacters(in: .whitespaces).isEmpty else {
            logger.e("track() called with blank event name — dropped")
            return
        }
        if debugMode { validateProperties(properties) }
        let model = eventBuilder.build(name: event, properties: properties)
        Task { await dispatcher.enqueue(model) }
    }

    func identify(_ userId: String) {
        guard !userId.trimmingCharacters(in: .whitespaces).isEmpty else {
            logger.e("identify() called with empty userId — ignored")
            return
        }
        // Skip if already identified as this user — avoids redundant disk writes.
        guard userId != identityStore.userId else { return }
        identityStore.userId = userId
        logger.d("Identified: \(userId)")
    }

    func reset() {
        identityStore.reset()
        sessionManager.reset()
        // clearSync() — NOT async Task. Must be synchronous so the very next
        // track() call sees empty super properties. The old approach
        // (Task { await .clear() }) was a race: guest events after logout
        // could still carry the previous user's email, tier, etc.
        superPropertiesStore.clearSync()
        Task { await dispatcher.clearQueue() }
        logger.d("Analytics reset")
    }

    func flush() {
        logger.d("Manual flush requested")
        Task { await dispatcher.flush() }
    }

    func registerSuperProperties(_ properties: [String: Any]) {
        if debugMode { validateProperties(properties) }
        // Fix: bridge actor register() via Task
        Task { await superPropertiesStore.register(properties) }
        logger.d("Super properties registered: \(Array(properties.keys))")
    }

    func unregisterSuperProperty(_ key: String) {
        Task { await superPropertiesStore.unregister(key) }
        logger.d("Super property unregistered: \(key)")
    }

    func clearSuperProperties() {
        Task { await superPropertiesStore.clear() }
        logger.d("Super properties cleared")
    }

    func trackScreen(_ name: String, properties: [String: Any]) {
        var merged = properties; merged["screen_name"] = name
        track("screen_viewed", properties: merged)
    }

    func setGroup(_ key: String, id: Any) {
        Task { await superPropertiesStore.register(["$group_\(key)": id]) }
        logger.d("Group set: \(key) = \(id)")
    }

    // MARK: - Validation

    private func validateProperties(_ properties: [String: Any]) {
        for key in properties.keys {
            if key.isEmpty      { logger.e("Empty property key detected") }
            if key.count > 256  { logger.e("Property key '\(key.prefix(40))…' > 256 chars") }
            if key.contains("\0") { logger.e("Property key contains null byte") }
        }
    }

    // MARK: - Background flush

    private func registerBackgroundNotification() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        // Resume the periodic flush timer when the app returns to the foreground.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }

    @objc private func appDidEnterBackground() {
        #if canImport(UIKit)
        // ── Background handling — three concerns ────────────────────────────
        //
        // 1. bgTaskId as `var`: the expiration closure captures `bgTaskId` by
        //    reference. A `let` constant can't be read inside the very expression
        //    that initialises it, so we pre-set to `.invalid` then assign.
        //
        // 2. Expiration handler passes `bgTaskId`, NOT `.invalid`: otherwise the
        //    real token is never released and iOS may terminate the process.
        //
        // 3. `flushAndWait()` instead of `flush()`: `flush()` only schedules work
        //    and returns immediately; the background task would end before events
        //    are delivered. `flushAndWait()` suspends until doFlush() exits.
        //
        // 4. `pauseTimerIfBackground(generation:)` stops the periodic timer so no
        //    further network activity occurs while the app is suspended.
        //    The generation token guards the ON_STOP/ON_START race: if the user
        //    returns to the app while the flush is still in-flight, `resumeTimer()`
        //    increments the generation so the stale pause call is a no-op.
        // ─────────────────────────────────────────────────────────────────────

        var bgTaskId = UIBackgroundTaskIdentifier.invalid
        bgTaskId = UIApplication.shared.beginBackgroundTask(withName: "LightAnalyticsFlush") {
            // System is reclaiming time: cancel flush and release the token.
            Task { await self.dispatcher.cancelFlush() }
            UIApplication.shared.endBackgroundTask(bgTaskId)
        }
        guard bgTaskId != .invalid else { return }

        Task {
            defer {
                Task { @MainActor in UIApplication.shared.endBackgroundTask(bgTaskId) }
            }
            // Grab the generation token BEFORE flushing. If the app returns to
            // foreground during the flush, resumeTimer() will advance the generation
            // and the pauseTimerIfBackground() call below becomes a no-op.
            let gen = await dispatcher.beginBackground()
            await dispatcher.flushAndWait()
            await dispatcher.pauseTimerIfBackground(generation: gen)
        }
        #endif
    }

    /// Called when the app returns to the foreground.
    /// Restarts the periodic flush timer that was paused on background entry.
    @objc private func appWillEnterForeground() {
        #if canImport(UIKit)
        Task { await dispatcher.resumeTimer() }
        #endif
    }
}
