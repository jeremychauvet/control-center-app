import AppKit
import SwiftUI

/// "About" pane: app icon, name, version/build, and bundle identifier — read from
/// the running bundle so they always match the shipped binary.
struct AboutSettingsView: View {
    private let info = AppInfo()

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.name)
                            .font(.title2).bold()
                        Text("Version \(info.version) (\(info.build))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section("Details") {
                LabeledContent("Version", value: info.version)
                LabeledContent("Build", value: info.build)
                LabeledContent("Bundle identifier", value: info.bundleIdentifier)
            }

            Section {
                Text("Made by Jeremy Chauvet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
    }
}

private struct AppInfo {
    let name: String
    let version: String
    let build: String
    let bundleIdentifier: String

    init() {
        let bundle = Bundle.main
        let info = bundle.infoDictionary ?? [:]
        self.name = (info["CFBundleName"] as? String)
            ?? (info["CFBundleDisplayName"] as? String)
            ?? ProcessInfo.processInfo.processName
        self.version = (info["CFBundleShortVersionString"] as? String) ?? "—"
        self.build = (info["CFBundleVersion"] as? String) ?? "—"
        self.bundleIdentifier = bundle.bundleIdentifier ?? "—"
    }
}
