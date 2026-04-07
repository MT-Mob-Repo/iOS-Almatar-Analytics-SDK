import Foundation

/// Lightweight user profile passed to `AlmtaarAnalytics.authorizeUser(_:)`.
///
/// Build from your existing `LocalProfile` at the call site:
///
/// ```swift
/// AlmtaarAnalytics.authorizeUser(
///     UserProfile(
///         id:          String(localProfile.id),
///         email:       localProfile.email,
///         firstName:   localProfile.firstName,
///         lastName:    localProfile.lastName,
///         phonePrefix: String(localProfile.phonePrefix),
///         phoneNumber: localProfile.phoneNumber,
///         nationality: localProfile.nationality,
///         language:    LocaleManager.language,
///         currency:    PriceManager.defaultCurrency?.nameLocalized
///     )
/// )
/// ```
public struct UserProfile: Sendable {
    public let id:          String
    public let email:       String
    public let firstName:   String
    public let lastName:    String
    public let phonePrefix: String
    public let phoneNumber: String
    public let nationality: String
    public let language:    String
    public let currency:    String?

    public init(
        id:          String,
        email:       String,
        firstName:   String,
        lastName:    String,
        phonePrefix: String,
        phoneNumber: String,
        nationality: String,
        language:    String,
        currency:    String? = nil
    ) {
        self.id          = id
        self.email       = email
        self.firstName   = firstName
        self.lastName    = lastName
        self.phonePrefix = phonePrefix
        self.phoneNumber = phoneNumber
        self.nationality = nationality
        self.language    = language
        self.currency    = currency
    }
}

/// Replaces `PrefsManager` calls inside `AlmtaarAnalytics.trackEvent`.
///
/// Set once in `AppDelegate` or `App.init()` after your prefs are ready:
///
/// ```swift
/// UserContext.originCountry = PrefsManager.getOriginCountry()
/// UserContext.marketCountry = PrefsManager.getMarketCountry()
/// ```
///
/// Values are automatically injected into every `trackEvent` call,
/// exactly as the original Mixpanel implementation did.
public final class UserContext: @unchecked Sendable {
    public static var originCountry: String = ""
    public static var marketCountry: String = ""
}
