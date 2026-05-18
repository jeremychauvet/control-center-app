import AppKit
import SwiftUI

/// The popover UI for the menu bar item.
struct SettingsView: View {
    @Environment(KeybindingStore.self) private var store
    @Environment(AccessibilityService.self) private var accessibility

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if !accessibility.isTrusted {
                permissionBanner
                Divider()
            }
            bindingsList
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Animate window snapping", isOn: $store.animationEnabled)
                    .toggleStyle(.switch)
                HStack {
                    Text("Duration")
                        .frame(width: 70, alignment: .leading)
                        .foregroundStyle(store.animationEnabled ? .primary : .secondary)
                    Slider(value: $store.animationDuration, in: 0.05...0.5)
                        .disabled(!store.animationEnabled)
                    Text("\(Int(store.animationDuration * 1000))ms")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
            footer
        }
        .frame(width: 360)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.split.2x2.fill")
                .foregroundStyle(.tint)
            Text("Window Snapping")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility permission required")
                        .font(.subheadline).bold()
                    Text("Control Center needs Accessibility access to move other apps' windows.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
        .padding(16)
        .background(Color.orange.opacity(0.08))
    }

    private var bindingsList: some View {
        VStack(spacing: 0) {
            ForEach(WindowAction.allCases) { action in
                HStack(spacing: 12) {
                    Image(systemName: action.systemImage)
                        .foregroundStyle(.tint)
                        .frame(width: 18)
                    Text(action.displayName)
                        .font(.body)
                    Spacer()
                    KeyRecorder(combo: Binding(
                        get: { store.bindings[action] },
                        set: { newValue in
                            if let newValue {
                                store.setBinding(newValue, for: action)
                            }
                        }
                    ))
                    .frame(width: 140, height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack {
            Button("Reset to defaults") {
                store.resetToDefaults()
            }
            .controlSize(.small)
            Spacer()
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    SettingsView()
        .environment(KeybindingStore())
        .environment(AccessibilityService())
}
