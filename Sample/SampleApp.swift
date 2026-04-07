import SwiftUI
import LightAnalytics

@main
struct SampleApp: App {
    init() {
        Analytics.initialize(
            config: AnalyticsConfig(
                debugUrl:             "https://alpha.example.com/analytics",
                productionUrl:        "https://api.example.com/analytics",
                flushBatchSize:       3,
                flushIntervalSeconds: 20,
                debug:                true   // true → debugUrl + console logs
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - ViewModel

final class SampleViewModel: ObservableObject {

    // Auth state
    @Published var loginInput:    String = "user-123"
    @Published var currentUserId: String = ""
    @Published var isLoggedIn:    Bool   = false

    // Counts shown in the banner
    @Published var superPropCount: Int = 0
    @Published var eventCount:     Int = 0

    // Live log
    @Published var logs: [LogEntry] = []

    struct LogEntry: Identifiable {
        let id   = UUID()
        let icon:   String
        let action: String
        let detail: String
    }

    // MARK: - Auth

    func login() {
        let userId = loginInput.trimmingCharacters(in: .whitespaces)
        guard !userId.isEmpty else { log("⚠️", "Login skipped", "userId is empty"); return }

        log("🔑", "identify()", "userId = \(userId)")
        Analytics.identify(userId)

        let superProps: [String: Any] = [
            "email":     "\(userId)@almatar.com",
            "user_tier": "gold",
            "platform":  "iOS",
            "login_ts":  Date()
        ]
        Analytics.registerSuperProperties(superProps)
        log("📌", "registerSuperProperties()", "\(superProps.keys.sorted().joined(separator: ", "))")

        Analytics.track("sign_in_completed", properties: ["method": "email"])
        log("📊", "track()", "sign_in_completed")

        currentUserId  = userId
        isLoggedIn     = true
        superPropCount = superProps.count
        eventCount    += 1
    }

    func logout() {
        log("💾", "flush()", "delivering queued events before reset")
        Analytics.flush()

        log("🔄", "reset()", "clearing userId, super props, queue")
        Analytics.reset()

        Analytics.track("sign_out_completed")
        log("📊", "track()", "sign_out_completed  (anonymous — no super props)")

        currentUserId  = ""
        isLoggedIn     = false
        superPropCount = 0
        eventCount    += 1
    }

    // MARK: - Events

    func trackFlightSearch() {
        Analytics.track("flight_search_started", properties: [
            "origin":      "RUH",
            "destination": "LHR",
            "departure":   Date(),
            "passengers":  2
        ])
        log("📊", "track()", "flight_search_started  (origin=RUH, departure=\(Date()))")
        eventCount += 1
    }

    func trackScreenView() {
        Analytics.trackScreen("home", properties: ["tab": "explore"])
        log("📺", "trackScreen()", "home  tab=explore")
        eventCount += 1
    }

    func trackAsGuest() {
        Analytics.track("deals_browsed", properties: [
            "category": "flights",
            "source":   "guest_home"
        ])
        log("👤", "track() — guest", "deals_browsed  (no userId, no super props)")
        eventCount += 1
    }

    func trackGuestSearch() {
        Analytics.track("flight_search_started", properties: [
            "origin":      "RUH",
            "destination": "DXB",
            "passengers":  1,
            "is_guest":    true
        ])
        log("👤", "track() — guest", "flight_search_started  (anonymous)")
        eventCount += 1
    }

    func manualFlush() {
        Analytics.flush()
        log("📤", "flush()", "manual flush requested")
    }

    // MARK: - Helpers

    private func log(_ icon: String, _ action: String, _ detail: String) {
        let entry = LogEntry(icon: icon, action: action, detail: detail)
        DispatchQueue.main.async { self.logs.insert(entry, at: 0) }
    }
}

// MARK: - Root View

struct ContentView: View {
    @StateObject private var vm = SampleViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AuthStatusBanner(vm: vm)
                    AuthFlowSection(vm: vm)
                    Divider()
                    EventSection(vm: vm)
                    if !vm.isLoggedIn {
                        GuestTrackingHint(vm: vm)
                    }
                    Divider()
                    LiveLogSection(logs: vm.logs)
                }
                .padding()
            }
            .navigationTitle("Almatar Analytics")
        }
    }
}

// MARK: - Auth Status Banner

struct AuthStatusBanner: View {
    @ObservedObject var vm: SampleViewModel

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: vm.isLoggedIn ? "person.fill.checkmark" : "person.fill.questionmark")
                    .foregroundColor(vm.isLoggedIn ? .green : .orange)
                Text(vm.isLoggedIn ? "Identified: \(vm.currentUserId)" : "Anonymous user")
                    .font(.headline)
                    .foregroundColor(vm.isLoggedIn ? .green : .orange)
            }
            HStack(spacing: 20) {
                Label("\(vm.superPropCount) super props", systemImage: "pin.fill")
                Label("\(vm.eventCount) events", systemImage: "chart.bar.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(vm.isLoggedIn ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(vm.isLoggedIn ? Color.green : Color.orange, lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Auth Flow Section

struct AuthFlowSection: View {
    @ObservedObject var vm: SampleViewModel

    var body: some View {
        GroupBox(label: Label("Auth Flow", systemImage: "key.fill")) {
            VStack(spacing: 10) {
                TextField("User ID", text: $vm.loginInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(vm.isLoggedIn)
                    .opacity(vm.isLoggedIn ? 0.5 : 1)

                HStack(spacing: 12) {
                    Button {
                        vm.login()
                    } label: {
                        Label("Login", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(vm.isLoggedIn)

                    Button {
                        vm.logout()
                    } label: {
                        Label("Logout", systemImage: "arrow.left.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!vm.isLoggedIn)
                }
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Event Section

struct EventSection: View {
    @ObservedObject var vm: SampleViewModel

    var body: some View {
        GroupBox(label: Label("Track Events", systemImage: "chart.bar")) {
            VStack(spacing: 8) {
                Button("✈️  Flight Search") { vm.trackFlightSearch() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button("📺  Screen View (home)") { vm.trackScreenView() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button("📤  Manual Flush") { vm.manualFlush() }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Guest Tracking Hint

struct GuestTrackingHint: View {
    @ObservedObject var vm: SampleViewModel

    var body: some View {
        GroupBox(label: Label("Guest Tracking (post-logout)", systemImage: "person.fill.questionmark")) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Events below carry a NEW anonymousId.\nNo userId, no super properties — proves reset() worked.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Button("Browse Deals") { vm.trackAsGuest() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                    Button("Search Flight") { vm.trackGuestSearch() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 2)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Live Log Section

struct LiveLogSection: View {
    let logs: [SampleViewModel.LogEntry]

    var body: some View {
        GroupBox(label: Label("Live Log", systemImage: "terminal")) {
            if logs.isEmpty {
                Text("No events yet — tap a button above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logs) { entry in
                        LogRowView(entry: entry)
                    }
                }
            }
        }
    }
}

struct LogRowView: View {
    let entry: SampleViewModel.LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(entry.icon)
                Text(entry.action)
                    .font(.caption.bold())
                    .foregroundColor(.primary)
            }
            Text(entry.detail)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(6)
    }
}
