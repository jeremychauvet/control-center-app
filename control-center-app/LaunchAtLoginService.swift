import Foundation
import Observation
import OSLog
import ServiceManagement

/// Wraps `SMAppService.mainApp` so the popover can toggle launch-at-login.
/// The actual enabled state lives in the system's Background Task Management
/// database; we mirror it here so SwiftUI can observe and drive a Toggle.
@MainActor
@Observable
final class LaunchAtLoginService {
    private(set) var isEnabled: Bool

    @ObservationIgnored
    private let service = SMAppService.mainApp

    @ObservationIgnored
    private static let logger = Logger(
        subsystem: "com.jeremychauvet.control-center-app",
        category: "LaunchAtLogin"
    )

    init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Re-read the system status (e.g. after the user toggled the entry in
    /// System Settings > General > Login Items).
    func refresh() {
        let enabled = service.status == .enabled
        if enabled != isEnabled { isEnabled = enabled }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            Self.logger.error(
                "Failed to \(enabled ? "register" : "unregister", privacy: .public) launch-at-login: \(error.localizedDescription, privacy: .public)"
            )
        }
        // Always reflect the real status — register/unregister can silently
        // land in a non-.enabled state if the user has denied the item.
        isEnabled = service.status == .enabled
    }
}
