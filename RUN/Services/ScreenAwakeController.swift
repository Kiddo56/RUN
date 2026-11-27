import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class ScreenAwakeController {
    static let shared = ScreenAwakeController()

    private(set) var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var recordingWantsAwake = false
    private var workoutWantsAwake = false
    private var powerObserver: NSObjectProtocol?

    private init() {
        powerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPowerState()
            }
        }
    }

    var isEffectivelyKeepingAwake: Bool {
        (recordingWantsAwake || workoutWantsAwake) && !isLowPowerModeEnabled
    }

    func setRecordingAwake(_ wantsAwake: Bool) {
        recordingWantsAwake = wantsAwake
        applyIdleTimer()
    }

    func setWorkoutAwake(_ wantsAwake: Bool) {
        workoutWantsAwake = wantsAwake
        applyIdleTimer()
    }

    private func refreshPowerState() {
        let nowLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        if nowLowPower != isLowPowerModeEnabled {
            isLowPowerModeEnabled = nowLowPower
            DiagnosticsLogger.shared.log(
                .lifecycle,
                "Low Power Mode changed -> \(nowLowPower ? "ON (screen awake paused)" : "OFF")"
            )
        }
        applyIdleTimer()
    }

    private func applyIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = isEffectivelyKeepingAwake
    }
}
