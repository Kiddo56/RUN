import AVFoundation
import Foundation
import Observation
import TrackerCore

private struct QueuedSpeechItem {
    let cue: SpokenCue
    let enqueuedAt: Date
    let maxAgeSeconds: TimeInterval
}

@MainActor
@Observable
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechService()

    private(set) var availableVoices: [VoiceDescriptor] = []
    private(set) var activeVoice: VoiceDescriptor?
    private(set) var isSpeaking = false

    var bestAvailableQuality: VoiceQualityRank {
        availableVoices.first?.quality ?? .defaultQuality
    }

    var shouldShowVoiceUpgradeHelpCard: Bool {
        bestAvailableQuality == .defaultQuality
    }

    private var synthesizer: AVSpeechSynthesizer?
    private var composer = PhraseComposer()
    private var queue: [QueuedSpeechItem] = []
    private var isInterrupted = false
    private var pendingSettings: AppSettingsStore?
    private var interruptionObserver: NSObjectProtocol?
    private var voiceRefreshTask: Task<Void, Never>?

    override init() {
        super.init()
        setupInterruptionObserver()
    }

    /// Asynchronously enumerates installed iOS voices off the main thread to keep app launch instant.
    func refreshAvailableVoices(settings: AppSettingsStore?) {
        if let settings {
            pendingSettings = settings
        }
        let localeID = Locale.current.identifier
        voiceRefreshTask?.cancel()
        voiceRefreshTask = Task { [weak self] in
            let ranked = await Task.detached(priority: .utility) { () -> [VoiceDescriptor] in
                let systemVoices = AVSpeechSynthesisVoice.speechVoices()
                let descriptors = systemVoices.map { voice in
                    VoiceDescriptor(
                        identifier: voice.identifier,
                        name: voice.name,
                        languageCode: voice.language,
                        quality: Self.mapQuality(voice.quality)
                    )
                }
                return VoiceRanker.rankVoices(descriptors, preferredLocaleIdentifier: localeID)
            }.value

            guard !Task.isCancelled, let self else { return }
            self.applyRankedVoices(ranked, settings: settings ?? self.pendingSettings)
        }
    }

    private func applyRankedVoices(_ ranked: [VoiceDescriptor], settings: AppSettingsStore?) {
        availableVoices = ranked
        let savedID = settings?.selectedVoiceIdentifier
        let resolved = VoiceRanker.resolveVoice(savedIdentifier: savedID, rankedVoices: ranked)
        activeVoice = resolved.selected

        if resolved.didFallbackFromMissingSaved {
            let fallbackName = resolved.selected?.name ?? "System Default"
            DiagnosticsLogger.shared.log(
                .lifecycle,
                "Saved voice '\(savedID ?? "")' no longer installed; fell back to '\(fallbackName)'"
            )
            if let newID = resolved.selected?.identifier {
                settings?.selectedVoiceIdentifier = newID
            }
        }
    }

    func selectVoice(identifier: String, settings: AppSettingsStore) {
        settings.selectedVoiceIdentifier = identifier
        if availableVoices.isEmpty {
            refreshAvailableVoices(settings: settings)
        } else {
            applyRankedVoices(availableVoices, settings: settings)
        }
    }

    func previewVoice(settings: AppSettingsStore) {
        let cue = PhraseComposer.previewSample(unit: settings.unitSystem)
        enqueue(cue, settings: settings, interruptCurrent: true, maxAgeSeconds: 10.0)
    }

    // MARK: - Domain Cue Entry Points (All Spoken Output Routes Here)

    func announceStart(type: ActivityType, settings: AppSettingsStore) {
        guard settings.audioCuesEnabled else { return }
        let cue = composer.composeStart(type: type)
        enqueue(cue, settings: settings, interruptCurrent: false)
    }

    func announcePause(auto: Bool, settings: AppSettingsStore) {
        guard settings.audioCuesEnabled, settings.cueOnPauseResumeEnabled else { return }
        let cue = composer.composePause(auto: auto)
        enqueue(cue, settings: settings, interruptCurrent: true)
    }

    func announceResume(auto: Bool, settings: AppSettingsStore) {
        guard settings.audioCuesEnabled, settings.cueOnPauseResumeEnabled else { return }
        let cue = composer.composeResume(auto: auto)
        enqueue(cue, settings: settings, interruptCurrent: true)
    }

    func announceSplit(
        _ split: ActivitySplit,
        type: ActivityType,
        totalDistanceMeters: Double,
        totalMovingTime: TimeInterval,
        settings: AppSettingsStore
    ) {
        guard settings.audioCuesEnabled, settings.cueEveryUnitEnabled else { return }
        let cue = composer.composeSplit(
            splitIndex: split.index,
            splitPaceSecondsPerMeter: split.paceSecondsPerMeter,
            splitSpeedMPS: split.speedMPS,
            totalDistanceMeters: totalDistanceMeters,
            totalMovingTime: totalMovingTime,
            type: type,
            unit: settings.unitSystem
        )
        enqueue(cue, settings: settings, interruptCurrent: false)
    }

    func announceTimeInterval(
        movingTime: TimeInterval,
        distanceMeters: Double,
        currentPaceSecondsPerMeter: Double,
        currentSpeedMPS: Double,
        type: ActivityType,
        settings: AppSettingsStore
    ) {
        guard settings.audioCuesEnabled, settings.cueEveryNMinutes > 0 else { return }
        let cue = composer.composeTimeInterval(
            movingTime: movingTime,
            distanceMeters: distanceMeters,
            currentPaceSecondsPerMeter: currentPaceSecondsPerMeter,
            currentSpeedMPS: currentSpeedMPS,
            type: type,
            unit: settings.unitSystem
        )
        enqueue(cue, settings: settings, interruptCurrent: false)
    }

    func announceLap(
        lapNumber: Int,
        lapDistanceMeters: Double,
        lapDuration: TimeInterval,
        settings: AppSettingsStore
    ) {
        guard settings.audioCuesEnabled, settings.cueOnLapEnabled else { return }
        let cue = composer.composeLap(
            lapNumber: lapNumber,
            lapDistanceMeters: lapDistanceMeters,
            lapDuration: lapDuration,
            unit: settings.unitSystem
        )
        enqueue(cue, settings: settings, interruptCurrent: false)
    }

    func announceFinish(distanceMeters: Double, movingTime: TimeInterval, settings: AppSettingsStore) {
        guard settings.audioCuesEnabled else { return }
        let cue = composer.composeFinish(
            distanceMeters: distanceMeters,
            movingTime: movingTime,
            unit: settings.unitSystem
        )
        enqueue(cue, settings: settings, interruptCurrent: false)
    }

    func announceOffRoute(distanceMeters: Double, settings: AppSettingsStore) {
        guard settings.audioCuesEnabled else { return }
        let cue = composer.composeOffRoute(distanceMeters: distanceMeters, unit: settings.unitSystem)
        enqueue(cue, settings: settings, interruptCurrent: false)
    }

    func announceGoalReached(goalTitle: String, settings: AppSettingsStore) {
        guard settings.audioCuesEnabled, settings.cueOnGoalReachedEnabled else { return }
        let cue = composer.composeGoalReached(goalTitle: goalTitle)
        enqueue(cue, settings: settings, interruptCurrent: false)
    }

    func announceRestTimerDone(nextExerciseName: String? = nil, settings: AppSettingsStore) {
        guard settings.audioCuesEnabled else { return }
        let cue = composer.composeRestTimerDone(nextExerciseName: nextExerciseName)
        enqueue(cue, settings: settings, interruptCurrent: true)
    }

    func announceWorkoutPR(exerciseName: String, settings: AppSettingsStore) {
        guard settings.audioCuesEnabled else { return }
        let cue = composer.composeWorkoutPR(exerciseName: exerciseName)
        enqueue(cue, settings: settings, interruptCurrent: false)
    }

    func announceWorkoutComplete(durationSeconds: TimeInterval, completedSets: Int, settings: AppSettingsStore) {
        guard settings.audioCuesEnabled else { return }
        let cue = composer.composeWorkoutComplete(durationSeconds: durationSeconds, completedSets: completedSets)
        enqueue(cue, settings: settings, interruptCurrent: false)
    }

    func stopAll() {
        queue.removeAll()
        if synthesizer?.isSpeaking == true {
            synthesizer?.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        deactivateAudioSessionIfIdle()
    }

    // MARK: - Queue & Audio Session Engine

    private func ensureSynthesizer() -> AVSpeechSynthesizer {
        if let synthesizer {
            return synthesizer
        }
        let synth = AVSpeechSynthesizer()
        synth.delegate = self
        synthesizer = synth
        return synth
    }

    private func enqueue(
        _ cue: SpokenCue,
        settings: AppSettingsStore,
        interruptCurrent: Bool,
        maxAgeSeconds: TimeInterval = 12.0
    ) {
        pendingSettings = settings
        guard !isInterrupted else { return }

        if interruptCurrent {
            queue.removeAll()
            if synthesizer?.isSpeaking == true {
                synthesizer?.stopSpeaking(at: .immediate)
            }
        }

        queue.append(QueuedSpeechItem(cue: cue, enqueuedAt: Date(), maxAgeSeconds: maxAgeSeconds))
        drainQueueIfIdle()
    }

    private func drainQueueIfIdle() {
        guard !isInterrupted, synthesizer?.isSpeaking != true else { return }
        let now = Date()

        while !queue.isEmpty {
            let item = queue.removeFirst()
            if now.timeIntervalSince(item.enqueuedAt) > item.maxAgeSeconds {
                DiagnosticsLogger.shared.log(.lifecycle, "Dropped stale speech cue (\(item.cue.kind.rawValue))")
                continue
            }
            speakNow(item.cue)
            return
        }

        isSpeaking = false
        deactivateAudioSessionIfIdle()
    }

    private func speakNow(_ cue: SpokenCue) {
        guard !cue.segments.isEmpty else {
            drainQueueIfIdle()
            return
        }

        activateAudioSession()
        let synth = ensureSynthesizer()
        let voice = resolveAVVoice()
        let rate = clampRate(pendingSettings?.speechRate ?? 0.47)
        let pitch = min(1.5, max(0.5, pendingSettings?.speechPitch ?? 1.0))
        let volume = min(1.0, max(0.1, pendingSettings?.speechVolume ?? 0.95))

        isSpeaking = true
        for seg in cue.segments {
            let utterance = AVSpeechUtterance(string: seg.text)
            if let voice {
                utterance.voice = voice
            }
            utterance.rate = rate
            utterance.pitchMultiplier = pitch
            utterance.volume = volume
            utterance.preUtteranceDelay = seg.preUtteranceDelay
            utterance.postUtteranceDelay = seg.postUtteranceDelay
            synth.speak(utterance)
        }
    }

    private func resolveAVVoice() -> AVSpeechSynthesisVoice? {
        if availableVoices.isEmpty {
            let localeID = Locale.current.identifier
            let descriptors = AVSpeechSynthesisVoice.speechVoices().map {
                VoiceDescriptor(
                    identifier: $0.identifier,
                    name: $0.name,
                    languageCode: $0.language,
                    quality: Self.mapQuality($0.quality)
                )
            }
            let ranked = VoiceRanker.rankVoices(descriptors, preferredLocaleIdentifier: localeID)
            applyRankedVoices(ranked, settings: pendingSettings)
        }
        // Always select by explicit identifier (never AVSpeechSynthesisVoice(language:))
        if let id = activeVoice?.identifier, let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        if let fallbackID = availableVoices.first?.identifier {
            return AVSpeechSynthesisVoice(identifier: fallbackID)
        }
        return nil
    }

    private func clampRate(_ raw: Float) -> Float {
        min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, raw))
    }

    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try session.setActive(true)
        } catch {
            DiagnosticsLogger.shared.log(.error, "SpeechService audio session activate failed: \(error.localizedDescription)")
        }
    }

    private func deactivateAudioSessionIfIdle() {
        guard synthesizer?.isSpeaking != true, queue.isEmpty else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-fatal if another app reclaimed audio focus.
        }
    }

    private nonisolated static func mapQuality(_ quality: AVSpeechSynthesisVoiceQuality) -> VoiceQualityRank {
        switch quality {
        case .premium: return .premium
        case .enhanced: return .enhanced
        default: return .defaultQuality
        }
    }

    private func setupInterruptionObserver() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self, let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
                switch type {
                case .began:
                    self.isInterrupted = true
                    self.queue.removeAll()
                    if self.synthesizer?.isSpeaking == true {
                        self.synthesizer?.stopSpeaking(at: .immediate)
                    }
                    self.isSpeaking = false
                    DiagnosticsLogger.shared.log(.lifecycle, "Audio session interrupted (paused speech)")
                case .ended:
                    self.isInterrupted = false
                    DiagnosticsLogger.shared.log(.lifecycle, "Audio session interruption ended")
                    self.drainQueueIfIdle()
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.synthesizer?.isSpeaking != true {
                self.drainQueueIfIdle()
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.synthesizer?.isSpeaking != true {
                self.drainQueueIfIdle()
            }
        }
    }
}
