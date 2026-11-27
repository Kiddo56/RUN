import SwiftUI
import TrackerCore

struct VoiceSettingsView: View {
    @Environment(AppSettingsStore.self) private var settings
    @Environment(SpeechService.self) private var speechService

    var body: some View {
        @Bindable var bindableSettings = settings

        Form {
            Section {
                Toggle("Enable Spoken Cues", isOn: $bindableSettings.audioCuesEnabled)

                Button {
                    speechService.previewVoice(settings: settings)
                } label: {
                    Label(
                        speechService.isSpeaking ? "Speaking Preview…" : "Preview Current Voice",
                        systemImage: "speaker.wave.2.fill"
                    )
                }
                .disabled(!settings.audioCuesEnabled)
            } header: {
                Text("Master Voice Control")
            } footer: {
                Text("Routes all run, ride, rest timer, and strength workout cues through one audio session that ducks background music.")
            }

            if speechService.shouldShowVoiceUpgradeHelpCard {
                Section {
                    upgradeVoiceHelpCard
                } header: {
                    Text("Get a More Natural Voice")
                }
            }

            Section {
                if speechService.availableVoices.isEmpty {
                    Text("No system speech voices found for your language.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(speechService.availableVoices) { voice in
                        voiceRow(voice)
                    }
                }
            } header: {
                Text("Installed System Voices")
            } footer: {
                Text("RUN automatically ranks Premium > Enhanced > Default voices and selects your voice by explicit identifier.")
            }

            Section("Voice Delivery") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Speech Rate")
                        Spacer()
                        Text(String(format: "%.2f", settings.speechRate))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $bindableSettings.speechRate, in: 0.35...0.60, step: 0.01)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Pitch")
                        Spacer()
                        Text(String(format: "%.2f", settings.speechPitch))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $bindableSettings.speechPitch, in: 0.80...1.20, step: 0.02)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text("\(Int((settings.speechVolume * 100).rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $bindableSettings.speechVolume, in: 0.20...1.0, step: 0.05)
                }

                Button("Reset Delivery to Natural Defaults") {
                    settings.speechRate = 0.47
                    settings.speechPitch = 1.0
                    settings.speechVolume = 0.95
                }
                .font(.caption.weight(.semibold))
            }

            Section("Spoken Cue Triggers") {
                Toggle("Every \(settings.unitSystem == .metric ? "Kilometre" : "Mile")", isOn: $bindableSettings.cueEveryUnitEnabled)

                Picker("Time Interval", selection: $bindableSettings.cueEveryNMinutes) {
                    Text("Off").tag(0)
                    Text("Every 3 min").tag(3)
                    Text("Every 5 min").tag(5)
                    Text("Every 10 min").tag(10)
                    Text("Every 15 min").tag(15)
                }

                Toggle("On Manual Lap", isOn: $bindableSettings.cueOnLapEnabled)
                Toggle("On Pause & Resume", isOn: $bindableSettings.cueOnPauseResumeEnabled)
                Toggle("On Goal Reached", isOn: $bindableSettings.cueOnGoalReachedEnabled)
            }
        }
        .navigationTitle("Voice & Cues")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            speechService.refreshAvailableVoices(settings: settings)
        }
    }

    @ViewBuilder
    private var upgradeVoiceHelpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Default-Quality Voices Only", systemImage: "waveform.and.magnifyingglass")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(RunTheme.electricTeal)

            Text("iOS only includes basic voices out of the box. You can download much more natural Enhanced or Premium voices directly from Apple in iPhone Settings (these are large downloads; iOS does not make Siri voices available to third-party apps).")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 5) {
                Text("1. Open the iPhone Settings app.")
                Text("2. Tap Accessibility > Spoken Content > Voices.")
                Text("3. Select your language (for example, English).")
                Text("4. Pick a voice marked Enhanced or Premium and tap the download icon.")
                Text("5. Wait for the download to finish, then return to RUN — this list updates automatically.")
            }
            .font(.caption.weight(.medium))
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func voiceRow(_ voice: VoiceDescriptor) -> some View {
        let isSelected = speechService.activeVoice?.identifier == voice.identifier
        Button {
            speechService.selectVoice(identifier: voice.identifier, settings: settings)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.name)
                        .font(.body.weight(isSelected ? .bold : .regular))
                        .foregroundStyle(.primary)
                    Text(voice.languageCode)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(voice.quality.label)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(qualityBadgeColor(voice.quality).opacity(0.18))
                    .foregroundStyle(qualityBadgeColor(voice.quality))
                    .clipShape(Capsule())

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(RunTheme.electricTeal)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(voice.name), \(voice.quality.label) quality\(isSelected ? ", selected" : "")")
    }

    private func qualityBadgeColor(_ quality: VoiceQualityRank) -> Color {
        switch quality {
        case .premium: return RunTheme.emerald
        case .enhanced: return RunTheme.electricTeal
        case .defaultQuality: return .secondary
        }
    }
}
