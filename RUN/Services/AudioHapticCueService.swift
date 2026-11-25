import AVFoundation
import Foundation
import TrackerCore
import UIKit

@MainActor
final class AudioHapticCueService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private let impactLight = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notifier = UINotificationFeedbackGenerator()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func countdownTick(hapticsEnabled: Bool) {
        guard hapticsEnabled else { return }
        impactLight.prepare()
        impactLight.impactOccurred()
    }

    func countdownGo(hapticsEnabled: Bool) {
        guard hapticsEnabled else { return }
        notifier.prepare()
        notifier.notificationOccurred(.success)
    }

    func stateChange(hapticsEnabled: Bool) {
        guard hapticsEnabled else { return }
        impactHeavy.prepare()
        impactHeavy.impactOccurred()
    }

    func splitMilestone(hapticsEnabled: Bool) {
        guard hapticsEnabled else { return }
        notifier.prepare()
        notifier.notificationOccurred(.success)
    }

    func announceStart(type: ActivityType, audioEnabled: Bool) {
        guard audioEnabled else { return }
        speak("\(type.displayName) started.")
    }

    func announcePause(auto: Bool, audioEnabled: Bool) {
        guard audioEnabled else { return }
        speak(auto ? "Activity auto paused." : "Activity paused.")
    }

    func announceResume(auto: Bool, audioEnabled: Bool) {
        guard audioEnabled else { return }
        speak(auto ? "Activity resumed." : "Resumed.")
    }

    func announceSplit(
        _ split: ActivitySplit,
        type: ActivityType,
        unitSystem: UnitSystem,
        totalDistanceMeters: Double,
        totalMovingTime: TimeInterval,
        audioEnabled: Bool
    ) {
        guard audioEnabled else { return }
        let unitWord = unitSystem == .metric ? "kilometer" : "mile"
        let splitRate: String
        if type.prefersSpeedOverPace {
            splitRate = "speed \(RunFormatter.speed(metersPerSecond: split.speedMPS, unit: unitSystem))"
        } else {
            splitRate = "split pace \(spokenDuration(split.paceSecondsPerMeter * unitSystem.metersPerMajorUnit))"
        }
        let totalTimeText = spokenDuration(totalMovingTime)
        let msg = "\(unitWord) \(split.index). Total distance \(RunFormatter.distance(meters: totalDistanceMeters, unit: unitSystem, decimals: 1)). Time \(totalTimeText). \(splitRate)."
        speak(msg)
    }

    func announceFinish(distanceMeters: Double, movingTime: TimeInterval, unitSystem: UnitSystem, audioEnabled: Bool) {
        guard audioEnabled else { return }
        let msg = "Activity completed. Distance \(RunFormatter.distance(meters: distanceMeters, unit: unitSystem)). Time \(spokenDuration(movingTime))."
        speak(msg)
    }

    private func speak(_ text: String) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try session.setActive(true)
        } catch {
            DiagnosticsLogger.shared.log(.error, "Audio session activation failed: \(error.localizedDescription)")
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    private func deactivateAudioSessionIfIdle() {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func spokenDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0 seconds" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) \(h == 1 ? "hour" : "hours")") }
        if m > 0 { parts.append("\(m) \(m == 1 ? "minute" : "minutes")") }
        if s > 0 || parts.isEmpty { parts.append("\(s) \(s == 1 ? "second" : "seconds")") }
        return parts.joined(separator: " ")
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.deactivateAudioSessionIfIdle()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.deactivateAudioSessionIfIdle()
        }
    }
}
