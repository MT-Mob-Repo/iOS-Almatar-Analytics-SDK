import Foundation

private let maxStringValueLength = 1024
private let maxKeyLength = 256

final class EventBuilder {
    private let contextProvider: ContextProvider
    private let identityStore: IdentityStore
    private let sessionManager: SessionManager
    private let superPropertiesStore: SuperPropertiesStore

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init(
        contextProvider: ContextProvider,
        identityStore: IdentityStore,
        sessionManager: SessionManager,
        superPropertiesStore: SuperPropertiesStore
    ) {
        self.contextProvider = contextProvider
        self.identityStore = identityStore
        self.sessionManager = sessionManager
        self.superPropertiesStore = superPropertiesStore
    }

    func build(name: String, properties: [String: Any]) -> EventModel {
        var merged = superPropertiesStore.snapshot()
        properties.forEach { merged[$0] = $1 }

        // Sanitise to prevent OOM: truncate oversized keys and string values
        let sanitised = Dictionary(uniqueKeysWithValues: merged.map { (k, v) -> (String, Any) in
            let safeKey = k.count > maxKeyLength ? String(k.prefix(maxKeyLength - 1)) + "…" : k
            let safeVal: Any
            if let s = v as? String, s.count > maxStringValueLength {
                safeVal = String(s.prefix(maxStringValueLength - 1)) + "…"
            } else {
                safeVal = v
            }
            return (safeKey, safeVal)
        })

        return EventModel(
            eventId:    UUID().uuidString,
            name:       name,
            timestamp:  Self.isoFormatter.string(from: Date()),
            userId:     identityStore.userId,
            anonymousId: identityStore.anonymousId,
            sessionId:  sessionManager.sessionId(),
            context:    contextProvider.buildContext(),
            properties: sanitised.mapValues { AnyCodable($0) }
        )
    }
}
