import SwiftUI

/// "Presence" pane: keep-me-available (idle-detection + F15 injection) with a live
/// activity readout, plus secondary options. Backed by `PresenceService`.
struct PresenceSettingsView: View {
    @Environment(PresenceService.self) private var presence
    @Environment(AccessibilityService.self) private var accessibility

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    var body: some View {
        @Bindable var presence = presence

        Form {
            Section {
                // Routed through setEnabled so enabling while untrusted prompts
                // for Accessibility rather than silently doing nothing.
                Toggle("Keep me available", isOn: Binding(
                    get: { presence.isEnabled },
                    set: { presence.setEnabled($0) }
                ))
            } header: {
                Text("Presence")
            } footer: {
                Text(presence.statusDescription)
            }

            if !accessibility.isTrusted {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Accessibility permission is required to simulate input.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Grant Accessibility Permission\u{2026}") {
                            accessibility.requestTrust()
                            accessibility.openAccessibilitySettings()
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("Idle Threshold") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Inject keep-alive after")
                        Spacer()
                        Text("\(Int(presence.idleThreshold))s")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $presence.idleThreshold, in: 30...300, step: 15)
                }
            }

            Section("Activity") {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let idle = presence.secondsSinceUserActivity()
                    LabeledContent("Last activity") {
                        Text(Self.relativeFormatter.localizedString(fromTimeInterval: -idle))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                if let last = presence.lastInjectionAt {
                    LabeledContent("Last keep-alive ping") {
                        Text(last.formatted(date: .omitted, time: .standard))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle("Keep the Mac awake while away", isOn: $presence.preventSleep)
                Toggle("Show in menu bar", isOn: $presence.showMenuBarIcon)
            } header: {
                Text("Options")
            } footer: {
                Text("Keeping the Mac awake prevents the display from sleeping so you stay visible. The menu-bar icon lets you toggle availability without opening this window.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Presence")
        .onAppear { accessibility.refresh() }
    }
}
