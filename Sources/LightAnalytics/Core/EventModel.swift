import Foundation

struct EventModel: Codable, Sendable {
    let eventId: String
    let name: String
    let timestamp: String
    let userId: String?
    let anonymousId: String
    let sessionId: String
    let context: EventContext
    let properties: [String: AnyCodable]

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "eventId": eventId,
            "name": name,
            "timestamp": timestamp,
            "anonymousId": anonymousId,
            "sessionId": sessionId,
            "context": context.toDictionary(),
            "properties": properties.mapValues { $0.value }
        ]
        if let uid = userId { dict["userId"] = uid }
        return dict
    }
}

struct EventContext: Codable, Sendable {
    let sdkName: String
    let sdkVersion: String
    let platform: String
    let appVersion: String
    let buildNumber: String
    let deviceModel: String
    let osVersion: String
    let locale: String
    let timezone: String

    func toDictionary() -> [String: Any] {
        ["sdkName": sdkName, "sdkVersion": sdkVersion, "platform": platform,
         "appVersion": appVersion, "buildNumber": buildNumber, "deviceModel": deviceModel,
         "osVersion": osVersion, "locale": locale, "timezone": timezone]
    }
}

/**
 * Type-preserving JSON wrapper.
 *
 * Supported types:
 *   Bool, Int, Double, String, Date
 *
 * Bool is decoded BEFORE Int so `true`/`false` round-trip correctly
 * (some decoders treat JSON booleans as valid integers).
 *
 * Date is encoded as an ISO-8601 UTC string ("2026-04-05T12:30:00Z").
 * On decode it comes back as a String — callers that need a Date object
 * should parse the string. This is intentional: JSON has no native date
 * type, so the string representation is the safest wire format.
 */
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    /// Shared ISO-8601 formatter — thread-safe, allocated once.
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self)   { value = v; return }  // ← Bool first
        if let v = try? c.decode(Int.self)    { value = v; return }
        if let v = try? c.decode(Double.self) { value = v; return }
        if let v = try? c.decode(String.self) { value = v; return }
        value = NSNull()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as Bool:   try c.encode(v)
        case let v as Int:    try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String: try c.encode(v)
        case let v as Date:   try c.encode(Self.isoFormatter.string(from: v))
        default:              try c.encodeNil()
        }
    }
}
