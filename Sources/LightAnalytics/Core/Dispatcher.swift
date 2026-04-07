import Foundation

/// Protocol so that unit tests can inject a mock transport without subclassing
/// the final `Transport` class.
protocol TransportProtocol: Sendable {
    func sendBatch(_ events: [EventModel]) async -> TransportResult
}

extension Transport: TransportProtocol {}

actor Dispatcher {
    private let queue: QueueStore
    private let transport: any TransportProtocol
    private let retryPolicy: RetryPolicy
    private let logger: LALogger
    private let batchSize: Int
    private let flushInterval: TimeInterval   // stored — needed for resumeTimer()

    private var flushTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    /// Monotonically increasing counter used to detect the background→foreground
    /// race: if `resumeTimer()` fires while `flushAndWait()` is still in-flight,
    /// it increments this value so any subsequent `pauseTimerIfBackground(generation:)`
    /// call from the now-stale background coroutine is safely ignored.
    private var backgroundGeneration = 0

    init(
        queue: QueueStore,
        transport: any TransportProtocol,
        retryPolicy: RetryPolicy,
        logger: LALogger,
        batchSize: Int,
        flushInterval: TimeInterval
    ) {
        self.queue         = queue
        self.transport     = transport
        self.retryPolicy   = retryPolicy
        self.logger        = logger
        self.batchSize     = batchSize
        self.flushInterval = flushInterval
        Task { await self.startTimer(interval: flushInterval) }
    }

    /// Cancel all background tasks to avoid leaking the timer and flush coroutines.
    func shutdown() {
        timerTask?.cancel()
        timerTask = nil
        flushTask?.cancel()
        flushTask = nil
    }

    func enqueue(_ event: EventModel) {
        guard !event.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            logger.e("Blank event name — dropped")
            return
        }
        queue.enqueue(event)
        logger.d("Event queued: \(event.name) (queue: \(queue.count()))")
        if queue.count() >= batchSize { scheduleFlush() }
    }

    func flush()      { scheduleFlush() }
    func clearQueue() { queue.clear() }

    // MARK: - Background lifecycle

    /// Call immediately when the app enters background (before launching the flush Task).
    /// Returns a generation token the caller must pass to `pauseTimerIfBackground(generation:)`.
    func beginBackground() -> Int {
        backgroundGeneration &+= 1
        return backgroundGeneration
    }

    /// Flush all queued events and suspend until delivery completes (or retries exhaust).
    ///
    /// Used by `appDidEnterBackground` so the background task token is held open for the
    /// entire flush. Unlike `flush()`, which only schedules work and returns immediately,
    /// this method awaits `flushTask?.value` — the real delivery coroutine.
    func flushAndWait() async {
        scheduleFlush()
        await flushTask?.value
    }

    /// Pause the periodic timer — but only if the generation token still matches.
    ///
    /// If the app returned to the foreground while `flushAndWait()` was in-flight,
    /// `resumeTimer()` will have already incremented `backgroundGeneration`, making
    /// the token stale. The guard prevents the timer from being killed in that case.
    func pauseTimerIfBackground(generation: Int) {
        guard backgroundGeneration == generation else {
            logger.d("Timer pause skipped — app already in foreground (gen mismatch)")
            return
        }
        timerTask?.cancel()
        timerTask = nil
        logger.d("Periodic timer paused (app in background)")
    }

    /// Resume the periodic timer after the app returns to the foreground.
    ///
    /// Also advances `backgroundGeneration` so any concurrent `pauseTimerIfBackground`
    /// call from the previous background cycle becomes a no-op.
    func resumeTimer() {
        backgroundGeneration &+= 1
        guard timerTask == nil || timerTask!.isCancelled else { return }
        startTimer(interval: flushInterval)
        // Immediately flush any events that were queued while the app was suspended
        // or that failed during the background flush window. Without this, they
        // would wait up to flushInterval seconds before the first periodic flush fires.
        scheduleFlush()
        logger.d("Periodic timer resumed (app in foreground) — immediate flush triggered")
    }

    /// Cancel the in-flight flush task without touching the periodic timer.
    ///
    /// Called from the iOS background-task expiration handler: the system is
    /// reclaiming time, so we must stop immediately and release the task token.
    func cancelFlush() {
        flushTask?.cancel()
        flushTask = nil
    }

    // MARK: - Private

    private func scheduleFlush() {
        if let existing = flushTask, !existing.isCancelled { return }
        flushTask = Task { await doFlush() }
    }

    private func startTimer(interval: TimeInterval) {
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                // `try?` swallows CancellationError. Check explicitly so we do NOT
                // fire one extra scheduleFlush() after the task has been cancelled.
                guard !Task.isCancelled else { break }
                scheduleFlush()
            }
        }
    }

    private func doFlush() async {
        logger.d("Flush started (queue: \(queue.count()))")
        var attempt = 0
        while true {
            let batch = queue.peek(limit: batchSize)
            guard !batch.isEmpty else { logger.d("Flush complete"); flushTask = nil; return }
            logger.d("Sending batch of \(batch.count) (attempt \(attempt + 1))")
            switch await transport.sendBatch(batch) {
            case .success:
                queue.remove(eventIds: batch.map { $0.eventId })
                logger.d("Batch sent (\(batch.count) events)")
                attempt = 0
            case .retryable(let reason):
                logger.e("Retryable: \(reason)")
                guard retryPolicy.shouldRetry(attempt: attempt) else {
                    logger.e("Max retries – dropping \(batch.count) events")
                    queue.remove(eventIds: batch.map { $0.eventId })
                    flushTask = nil; return
                }
                try? await Task.sleep(for: .seconds(retryPolicy.delay(attempt: attempt)))
                // `try?` swallows CancellationError — check explicitly so a cancelled
                // flush (e.g. from the background-task expiration handler) stops retrying
                // immediately rather than sleeping through the full back-off duration.
                if Task.isCancelled { flushTask = nil; return }
                attempt += 1
            case .fatal(let reason):
                logger.e("Fatal: \(reason)")
                queue.remove(eventIds: batch.map { $0.eventId })
                flushTask = nil; return
            }
        }
    }
}
