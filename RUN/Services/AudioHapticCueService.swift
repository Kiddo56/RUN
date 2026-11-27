import Foundation
import TrackerCore
import UIKit

@MainActor
final class AudioHapticCueService {
    private let impactLight = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notifier = UINotificationFeedbackGenerator()

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

    func warningHaptic(hapticsEnabled: Bool) {
        guard hapticsEnabled else { return }
        notifier.prepare()
        notifier.notificationOccurred(.warning)
    }

    func announceStart(type: ActivityType, settings: AppSettingsStore) {
        SpeechService.shared.announceStart(type: type, settings: settings)
    }

    func announcePause(auto: Bool, settings: AppSettingsStore) {
        SpeechService.shared.announcePause(auto: auto, settings: settings)
    }

    func announceResume(auto: Bool, settings: AppSettingsStore) {
        SpeechService.shared.announceResume(auto: auto, settings: settings)
    }

    func announceSplit(
        _ split: ActivitySplit,
        type: ActivityType,
        totalDistanceMeters: Double,
        totalMovingTime: TimeInterval,
        settings: AppSettingsStore
    ) {
        SpeechService.shared.announceSplit(
            split,
            type: type,
            totalDistanceMeters: totalDistanceMeters,
            totalMovingTime: totalMovingTime,
            settings: settings
        )
    }

    func announceTimeInterval(
        movingTime: TimeInterval,
        distanceMeters: Double,
        currentPaceSecondsPerMeter: Double,
        currentSpeedMPS: Double,
        type: ActivityType,
        settings: AppSettingsStore
    ) {
        SpeechService.shared.announceTimeInterval(
            movingTime: movingTime,
            distanceMeters: distanceMeters,
            currentPaceSecondsPerMeter: currentPaceSecondsPerMeter,
            currentSpeedMPS: currentSpeedMPS,
            type: type,
            settings: settings
        )
    }

    func announceLap(
        lapNumber: Int,
        lapDistanceMeters: Double,
        lapDuration: TimeInterval,
        settings: AppSettingsStore
    ) {
        splitMilestone(hapticsEnabled: settings.hapticsEnabled)
        SpeechService.shared.announceLap(
            lapNumber: lapNumber,
            lapDistanceMeters: lapDistanceMeters,
            lapDuration: lapDuration,
            settings: settings
        )
    }

    func announceFinish(distanceMeters: Double, movingTime: TimeInterval, settings: AppSettingsStore) {
        SpeechService.shared.announceFinish(
            distanceMeters: distanceMeters,
            movingTime: movingTime,
            settings: settings
        )
    }

    func offRouteAlert(distanceMeters: Double, settings: AppSettingsStore) {
        warningHaptic(hapticsEnabled: settings.hapticsEnabled)
        SpeechService.shared.announceOffRoute(distanceMeters: distanceMeters, settings: settings)
    }

    func announceGoalReached(goalTitle: String, settings: AppSettingsStore) {
        splitMilestone(hapticsEnabled: settings.hapticsEnabled)
        SpeechService.shared.announceGoalReached(goalTitle: goalTitle, settings: settings)
    }
}
