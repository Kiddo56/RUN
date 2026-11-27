import SwiftData
import SwiftUI
import TrackerCore

struct SettingsView: View {
    @Environment(AppSettingsStore.self) private var settings
    @Environment(DiagnosticsLogger.self) private var diagnostics
    @Environment(SpeechService.self) private var speechService
    @Query private var activities: [SDActivity]

    @State private var navigateToBackup = false

    private let buildInfo = AppBuildInfo.current()

    var body: some View {
        @Bindable var bindableSettings = settings

        NavigationStack {
            Form {
                if settings.needsBackupReminder(activityCount: activities.count) {
                    Section {
                        BackupReminderBanner(daysSinceBackup: settings.daysSinceLastBackup()) {
                            navigateToBackup = true
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                Section("Backup, Import & Export") {
                    NavigationLink(destination: DataAndBackupView()) {
                        HStack {
                            Label("Backup, GPX & CSV", systemImage: "externaldrive.fill")
                            Spacer()
                            if let last = settings.lastBackupDate {
                                Text(last.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

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

                Section("Voice & Spoken Cues") {
                    NavigationLink(destination: VoiceSettingsView()) {
                        HStack {
                            Label("Voice", systemImage: "waveform.circle.fill")
                            Spacer()
                            if let active = speechService.activeVoice {
                                Text("\(active.name) (\(active.quality.label))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(settings.audioCuesEnabled ? "System" : "Off")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Auto-Pause When Stopped", isOn: $bindableSettings.autoPauseEnabled)
                    Toggle("Keep Screen Awake While Recording", isOn: $bindableSettings.keepScreenAwakeWhileRecording)
                    Toggle("Haptic Feedback", isOn: $bindableSettings.hapticsEnabled)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("GPS Accuracy Filter")
                            Spacer()
                            Text("≤ \(Int(settings.maxHorizontalAccuracyMeters)) m")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $bindableSettings.maxHorizontalAccuracyMeters, in: 15...60, step: 5)
                    }

                    Stepper(value: $bindableSettings.userWeightKg, in: 35...180, step: 1) {
                        HStack {
                            Text("Body Weight (for Estimates)")
                            Spacer()
                            Text("\(Int(settings.userWeightKg)) kg")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Recording Preferences")
                } footer: {
                    Text("GPS fixes worse than the accuracy threshold are filtered out automatically. Keeping the screen awake uses extra battery and pauses automatically in iOS Low Power Mode.")
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
            .navigationDestination(isPresented: $navigateToBackup) {
                DataAndBackupView()
            }
        }
    }
}
