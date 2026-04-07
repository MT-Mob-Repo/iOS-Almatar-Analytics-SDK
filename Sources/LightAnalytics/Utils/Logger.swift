import Foundation

/// Developer-facing logger. All output is gated by `debug` — zero overhead
/// and zero console noise in production builds.
///
/// Why `print()` instead of `os.log Logger.debug()`:
/// Apple's unified logging system does NOT forward `.debug`-level messages to the
/// Xcode console when running on a **real device** (only on the simulator).
/// On device, `.debug` entries are stored in the ephemeral on-device ring buffer
/// and are only visible via Console.app with a USB-connected device.
///
/// `print()` writes to stdout, which Xcode always pipes to the console on both
/// simulator and real hardware — making it the correct choice for a developer
/// debug logger that must work out-of-the-box without extra tooling.
final class LALogger {
    private let debug: Bool
    private let tag = "[LightAnalytics]"

    init(debug: Bool) { self.debug = debug }

    /// Informational / debug message.
    func d(_ message: String) {
        guard debug else { return }
        print("🔵 \(tag) \(message)")
    }

    /// Error / warning message.
    func e(_ message: String) {
        guard debug else { return }
        print("🔴 \(tag) \(message)")
    }
}
