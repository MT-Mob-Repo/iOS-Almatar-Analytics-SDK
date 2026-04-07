import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Builds the static device/app context that is attached to every event.
/// Values are captured once at init time to avoid repeated system calls.
/// Single source of truth for the SDK version — update here on each release.
let kSDKVersion = "1.0.0"

final class ContextProvider {
    private let sdkName = "almatar-analytics-ios"

    private let appVersion: String
    private let buildNumber: String
    private let deviceModel: String
    private let osVersion: String

    init() {
        let bundle = Bundle.main
        appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

        #if canImport(UIKit)
        deviceModel = UIDevice.current.model
        osVersion = UIDevice.current.systemVersion
        #else
        deviceModel = "Mac"
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    func buildContext() -> EventContext {
        EventContext(
            sdkName: sdkName,
            sdkVersion: kSDKVersion,
            platform: "ios",
            appVersion: appVersion,
            buildNumber: buildNumber,
            deviceModel: deviceModel,
            osVersion: osVersion,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier
        )
    }
}
