import SwiftUI

/// Root of the Control Center settings window: a sidebar listing feature groups,
/// with a detail pane per selection. Hosted in an `NSWindow` by
/// `SettingsWindowController`.
struct ControlCenterView: View {
    enum Pane: String, CaseIterable, Identifiable, Hashable {
        case windowSnapping
        case presence
        case keepAwake
        case general
        case about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .windowSnapping: return "Window Snapping"
            case .presence: return "Presence"
            case .keepAwake: return "Keep Awake"
            case .general: return "General"
            case .about: return "About"
            }
        }

        var systemImage: String {
            switch self {
            case .windowSnapping: return "rectangle.split.2x2.fill"
            case .presence: return "cup.and.saucer.fill"
            case .keepAwake: return "powersleep"
            case .general: return "gearshape.fill"
            case .about: return "info.circle.fill"
            }
        }
    }

    @State private var selection: Pane? = .windowSnapping

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(Pane.allCases) { pane in
                    Label(pane.title, systemImage: pane.systemImage)
                        .tag(pane)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .navigationTitle("Control Center")
        } detail: {
            detail
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .windowSnapping {
        case .windowSnapping: WindowSnappingSettingsView()
        case .presence: PresenceSettingsView()
        case .keepAwake: KeepAwakeSettingsView()
        case .general: GeneralSettingsView()
        case .about: AboutSettingsView()
        }
    }
}

#Preview {
    ControlCenterView()
        .environment(KeybindingStore())
        .environment(AccessibilityService())
        .environment(LaunchAtLoginService())
        .environment(PresenceService(accessibility: AccessibilityService()))
        .environment(KeepAwakeService())
}
