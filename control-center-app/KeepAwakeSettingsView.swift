import SwiftUI

/// "Keep Awake" pane: a single toggle backed by `KeepAwakeService` that holds an
/// `IOPMAssertion` to prevent the display from sleeping. Unrelated to Presence.
struct KeepAwakeSettingsView: View {
    @Environment(KeepAwakeService.self) private var keepAwake

    var body: some View {
        @Bindable var keepAwake = keepAwake

        Form {
            Section {
                Toggle("Keep the Mac awake", isOn: $keepAwake.isEnabled)
            } header: {
                Text("Keep Awake")
            } footer: {
                Text("Prevents the display from sleeping while the Mac is unattended. No permissions required.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Keep Awake")
    }
}
