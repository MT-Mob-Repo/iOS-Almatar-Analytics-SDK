// swift-tools-version: 5.10
import PackageDescription

// ─────────────────────────────────────────────────────────────────────────────
// LightAnalytics SDK — Package.swift
//
// Swift 5.10 / Xcode 15.3+:
// - .enableUpcomingFeature("StrictConcurrency") replaces the deprecated
//   .enableExperimentalFeature("StrictConcurrency"). Catches data races at
//   compile time. Equivalent to Swift 6 concurrency enforcement without
//   requiring a full language mode bump.
// - iOS 16 minimum: required for Task.sleep(for: Duration) and
//   NotificationCenter async sequence API.
// ─────────────────────────────────────────────────────────────────────────────
let package = Package(
    name: "LightAnalytics",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "LightAnalytics", targets: ["LightAnalytics"]),
    ],
    targets: [
        .target(
            name: "LightAnalytics",
            path: "Sources/LightAnalytics",
            swiftSettings: [
                // Catches data races and Sendable violations at compile time.
                // Prefer this over .enableExperimentalFeature (deprecated in Swift 5.10).
                .enableUpcomingFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                // sqlite3 is bundled on all Apple platforms — zero third-party dependency.
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "LightAnalyticsTests",
            dependencies: ["LightAnalytics"],
            path: "Tests/LightAnalyticsTests"
        ),
    ]
)
