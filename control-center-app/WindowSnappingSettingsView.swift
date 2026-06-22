import SwiftUI

/// "Window Snapping" pane: editable keyboard shortcuts plus snap-animation settings.
struct WindowSnappingSettingsView: View {
    @Environment(KeybindingStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section("Keyboard Shortcuts") {
                ForEach(WindowAction.allCases) { action in
                    HStack(spacing: 12) {
                        Label(action.displayName, systemImage: action.systemImage)
                        Spacer()
                        KeyRecorder(combo: Binding(
                            get: { store.bindings[action] },
                            set: { newValue in
                                if let newValue {
                                    store.setBinding(newValue, for: action)
                                }
                            }
                        ))
                        .frame(width: 160, height: 24)
                    }
                }
            }

            Section("Animation") {
                Toggle("Animate window snapping", isOn: $store.animationEnabled)
                HStack {
                    Text("Duration")
                    Slider(value: $store.animationDuration, in: 0.05...0.5)
                        .disabled(!store.animationEnabled)
                    Text("\(Int(store.animationDuration * 1000))ms")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Window Snapping")
    }
}
