import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum ProtectionStatus: Equatable {
        case active
        case paused
        case needsPermission
        case starting
        case failed(String)

        var title: String {
            switch self {
            case .active: "Protection active"
            case .paused: "Protection paused"
            case .needsPermission: "Accessibility access required"
            case .starting: "Starting…"
            case .failed: "Protection unavailable"
            }
        }

        var detail: String {
            switch self {
            case .active: "Clicks immediately after typing are ignored."
            case .paused: "All clicks pass through normally."
            case .needsPermission: "Grant access once so TouchGuard can filter accidental clicks."
            case .starting: "Connecting to the macOS input event stream."
            case let .failed(message): message
            }
        }

        var symbolName: String {
            switch self {
            case .active: "hand.raised.fill"
            case .paused: "hand.raised.slash"
            case .needsPermission, .failed: "exclamationmark.triangle.fill"
            case .starting: "ellipsis.circle"
            }
        }
    }

    @Published var protectionEnabled: Bool {
        didSet {
            defaults.set(protectionEnabled, forKey: Keys.protectionEnabled)
            eventTapController.setProtectionEnabled(protectionEnabled)
            refresh()
        }
    }

    @Published var intervalSeconds: Double {
        didSet {
            defaults.set(intervalSeconds, forKey: Keys.intervalSeconds)
            eventTapController.setInterval(seconds: intervalSeconds)
        }
    }

    @Published private(set) var permissionGranted = false
    @Published private(set) var eventTapSnapshot = EventTapSnapshot(
        lifecycle: .stopped,
        tapEnabled: false,
        recoveryCount: 0
    )
    @Published private(set) var launchAtLoginStatus = SMAppService.mainApp.status
    @Published var lastError: String?

    private let defaults: UserDefaults
    private let eventTapController = EventTapController()
    private var monitorTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        protectionEnabled = defaults.object(forKey: Keys.protectionEnabled) as? Bool ?? true
        intervalSeconds = defaults.object(forKey: Keys.intervalSeconds) as? Double ?? 0.2
        eventTapController.setProtectionEnabled(protectionEnabled)
        eventTapController.setInterval(seconds: intervalSeconds)
        refresh()

        if !permissionGranted && !defaults.bool(forKey: Keys.requestedAccessibilityAccess) {
            defaults.set(true, forKey: Keys.requestedAccessibilityAccess)
            AccessibilityPermission.request()
        }

        if !defaults.bool(forKey: Keys.configuredLaunchAtLogin) {
            defaults.set(true, forKey: Keys.configuredLaunchAtLogin)
            do {
                try LaunchAtLoginController.setEnabled(true)
            } catch {
                lastError = "Launch at Login: \(error.localizedDescription)"
            }
            refresh()
        }

        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    deinit {
        monitorTask?.cancel()
    }

    var protectionStatus: ProtectionStatus {
        guard permissionGranted else {
            return .needsPermission
        }
        guard protectionEnabled else {
            return .paused
        }

        switch eventTapSnapshot.lifecycle {
        case .stopped, .starting:
            return .starting
        case .running:
            return eventTapSnapshot.tapEnabled
                ? .active
                : .failed("The input event tap is disabled.")
        case let .failed(message):
            return .failed(message)
        }
    }

    var launchAtLoginEnabled: Bool {
        launchAtLoginStatus == .enabled
    }

    var launchAtLoginNeedsApproval: Bool {
        launchAtLoginStatus == .requiresApproval
    }

    func requestAccessibilityAccess() {
        AccessibilityPermission.request()
        refresh()
    }

    func retryEventTap() {
        guard permissionGranted else {
            requestAccessibilityAccess()
            return
        }
        eventTapController.start()
        refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginController.setEnabled(enabled)
            lastError = nil
        } catch {
            lastError = "Launch at Login: \(error.localizedDescription)"
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func refresh() {
        let wasGranted = permissionGranted
        permissionGranted = AccessibilityPermission.isGranted
        eventTapSnapshot = eventTapController.snapshot()
        launchAtLoginStatus = LaunchAtLoginController.status

        if permissionGranted && (!wasGranted || eventTapSnapshot.lifecycle == .stopped) {
            eventTapController.start()
            eventTapSnapshot = eventTapController.snapshot()
        } else if !permissionGranted && wasGranted {
            eventTapController.stop()
        }
    }

    private enum Keys {
        static let protectionEnabled = "protectionEnabled"
        static let intervalSeconds = "intervalSeconds"
        static let requestedAccessibilityAccess = "requestedAccessibilityAccess"
        static let configuredLaunchAtLogin = "configuredLaunchAtLogin"
    }
}
