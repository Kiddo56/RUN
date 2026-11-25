import SwiftUI
import TrackerCore

struct SettingsView: View {
    @Environment(AppSettingsStore.self) private var settings
    @Environment(DiagnosticsLogger.self) private var diagnostics

    private let buildInfo = AppBuildInfo.current()

    var body: some View {
        @Bindable var bindableSettings = settings

        NavigationStack {
            Form {
                Section {
                    Picker("Units", selection: $bindableSettings.unitSystem) {
                        ForEach(UnitSystem.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Display Units")
                } footer: {
                    Text("Metric (km, min/km, m) is enabled by default.")
                }

                Section {
                    Toggle("Bluetooth Heart-Rate Strap", isOn: $bindableSettings.featureFlags.bleHeartRate)
                    Toggle("Barometric Altimeter", isOn: $bindableSettings.featureFlags.barometricAltimeter)
                    Toggle("Personal Sections", isOn: $bindableSettings.featureFlags.personalSections)
                    Toggle("Personal Heatmap", isOn: $bindableSettings.featureFlags.personalHeatmap)
                } header: {
                    Text("Optional Features")
                } footer: {
                    Text("All optional features run strictly on-device with your own data and start disabled.")
                }

                Section("Diagnostics") {
                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        HStack {
                            Label("Diagnostics & Logs", systemImage: "waveform.path.ecg")
                            Spacer()
                            Text("\(diagnostics.entries.count)")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings.diagnosticsLink")
                }

                Section("About") {
                    LabeledContent("App Name", value: buildInfo.appName)

                    LabeledContent("Version", value: buildInfo.versionDisplay)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("settings.version")

                    LabeledContent("Commit SHA", value: buildInfo.commitSHA)
                        .font(.body.monospaced())
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("settings.commitSHA")

                    LabeledContent("Bundle ID", value: buildInfo.bundleIdentifier)
                        .font(.footnote.monospaced())
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("settings.bundleID")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
