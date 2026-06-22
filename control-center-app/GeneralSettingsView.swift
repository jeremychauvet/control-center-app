import AppKit
import SwiftUI

/// "General" pane: app-wide settings (launch at login), the global Accessibility
/// permission banner, and reset/quit actions.
struct GeneralSettingsView: View {
    @Environment(KeybindingStore.self) private var store
    @Environment(AccessibilityService.self) private var accessibility
    @Environment(LaunchAtLoginService.self) private var launchAtLogin

    var body: some View {
        Form {
            if !accessibility.isTrusted {
                Section {
                    permissionBanner
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
            }

            Section("Window Snapping") {
                Button("Reset keyboard shortcuts to defaults") {
                    store.resetToDefaults()
                }
            }

            Section {
                Button("Quit Control Center") {
                    NSApp.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .onAppear { launchAtLogin.refresh() }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility permission required")
                        .font(.subheadline).bold()
                    Text("Control Center needs Accessibility access to move other apps' windows and simulate input.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Already checked but not working? Remove the existing **Control Center** entry in System Settings → Privacy & Security → Accessibility (select it, click –), then click Grant Permission below to re-add it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            HStack {
                Button("Grant Permission\u{2026}") {
                    accessibility.requestTrust()
                    accessibility.openAccessibilitySettings()
                }
                .controlSize(.small)
                Button("Re-check") {
                    accessibility.refresh()
                }
                .controlSize(.small)
            }
        }
    }
}
