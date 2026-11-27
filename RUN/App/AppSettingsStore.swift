import Foundation
import Observation
import TrackerCore

@MainActor
@Observable
final class AppSettingsStore {
    private enum Keys {
        static let unitSystem = "run.settings.unitSystem"
        static let weightUnit = "run.settings.weightUnit"
        static let featureFlags = "run.settings.featureFlags"
        static let autoPauseEnabled = "run.settings.autoPauseEnabled"
        static let audioCuesEnabled = "run.settings.audioCuesEnabled"
        static let hapticsEnabled = "run.settings.hapticsEnabled"
        static let maxHorizontalAccuracyMeters = "run.settings.maxHorizontalAccuracyMeters"
        static let elevationHysteresisMeters = "run.settings.elevationHysteresisMeters"
        static let userWeightKg = "run.settings.userWeightKg"
        static let privacyHideRadiusMeters = "run.settings.privacyHideRadiusMeters"
        static let lastBackupDate = "run.settings.lastBackupDate"

        // v1.1 screen awake, voice & strength settings
        static let keepScreenAwakeWhileRecording = "run.settings.keepScreenAwakeWhileRecording"
        static let keepScreenAwakeDuringWorkout = "run.settings.keepScreenAwakeDuringWorkout"
        static let selectedVoiceIdentifier = "run.settings.selectedVoiceIdentifier"
        static let speechRate = "run.settings.speechRate"
        static let speechPitch = "run.settings.speechPitch"
        static let speechVolume = "run.settings.speechVolume"
        static let cueEveryUnitEnabled = "run.settings.cueEveryUnitEnabled"
        static let cueEveryNMinutes = "run.settings.cueEveryNMinutes"
        static let cueOnLapEnabled = "run.settings.cueOnLapEnabled"
        static let cueOnPauseResumeEnabled = "run.settings.cueOnPauseResumeEnabled"
        static let cueOnGoalReachedEnabled = "run.settings.cueOnGoalReachedEnabled"
        static let defaultRestSeconds = "run.settings.defaultRestSeconds"
    }

    private let defaults: UserDefaults

    var unitSystem: UnitSystem {
        didSet { defaults.set(unitSystem.rawValue, forKey: Keys.unitSystem) }
    }

    var weightUnit: WeightUnit {
        didSet { defaults.set(weightUnit.rawValue, forKey: Keys.weightUnit) }
    }

    var featureFlags: FeatureFlags {
        didSet {
            if let data = try? JSONEncoder().encode(featureFlags) {
                defaults.set(data, forKey: Keys.featureFlags)
            }
        }
    }

    var autoPauseEnabled: Bool {
        didSet { defaults.set(autoPauseEnabled, forKey: Keys.autoPauseEnabled) }
    }

    var audioCuesEnabled: Bool {
        didSet { defaults.set(audioCuesEnabled, forKey: Keys.audioCuesEnabled) }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    var maxHorizontalAccuracyMeters: Double {
        didSet { defaults.set(maxHorizontalAccuracyMeters, forKey: Keys.maxHorizontalAccuracyMeters) }
    }

    var elevationHysteresisMeters: Double {
        didSet { defaults.set(elevationHysteresisMeters, forKey: Keys.elevationHysteresisMeters) }
    }

    var userWeightKg: Double {
        didSet { defaults.set(userWeightKg, forKey: Keys.userWeightKg) }
    }

    var privacyHideRadiusMeters: Double {
        didSet { defaults.set(privacyHideRadiusMeters, forKey: Keys.privacyHideRadiusMeters) }
    }

    var lastBackupDate: Date? {
        didSet { defaults.set(lastBackupDate, forKey: Keys.lastBackupDate) }
    }

    var keepScreenAwakeWhileRecording: Bool {
        didSet { defaults.set(keepScreenAwakeWhileRecording, forKey: Keys.keepScreenAwakeWhileRecording) }
    }

    var keepScreenAwakeDuringWorkout: Bool {
        didSet { defaults.set(keepScreenAwakeDuringWorkout, forKey: Keys.keepScreenAwakeDuringWorkout) }
    }

    var selectedVoiceIdentifier: String? {
        didSet {
            if let selectedVoiceIdentifier {
                defaults.set(selectedVoiceIdentifier, forKey: Keys.selectedVoiceIdentifier)
            } else {
                defaults.removeObject(forKey: Keys.selectedVoiceIdentifier)
            }
        }
    }

    /// Slightly slower than iOS default (`0.50`) for clearer, more natural outdoor delivery.
    var speechRate: Float {
        didSet { defaults.set(speechRate, forKey: Keys.speechRate) }
    }

    var speechPitch: Float {
        didSet { defaults.set(speechPitch, forKey: Keys.speechPitch) }
    }

    var speechVolume: Float {
        didSet { defaults.set(speechVolume, forKey: Keys.speechVolume) }
    }

    var cueEveryUnitEnabled: Bool {
        didSet { defaults.set(cueEveryUnitEnabled, forKey: Keys.cueEveryUnitEnabled) }
    }

    /// 0 disables time-interval cues; positive values speak every N minutes.
    var cueEveryNMinutes: Int {
        didSet { defaults.set(cueEveryNMinutes, forKey: Keys.cueEveryNMinutes) }
    }

    var cueOnLapEnabled: Bool {
        didSet { defaults.set(cueOnLapEnabled, forKey: Keys.cueOnLapEnabled) }
    }

    var cueOnPauseResumeEnabled: Bool {
        didSet { defaults.set(cueOnPauseResumeEnabled, forKey: Keys.cueOnPauseResumeEnabled) }
    }

    var cueOnGoalReachedEnabled: Bool {
        didSet { defaults.set(cueOnGoalReachedEnabled, forKey: Keys.cueOnGoalReachedEnabled) }
    }

    var defaultRestSeconds: Int {
        didSet { defaults.set(defaultRestSeconds, forKey: Keys.defaultRestSeconds) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults

        if let rawUnit = userDefaults.string(forKey: Keys.unitSystem),
           let parsedUnit = UnitSystem(rawValue: rawUnit) {
            self.unitSystem = parsedUnit
        } else {
            self.unitSystem = .metric
        }

        if let rawWeight = userDefaults.string(forKey: Keys.weightUnit),
           let parsedWeight = WeightUnit(rawValue: rawWeight) {
            self.weightUnit = parsedWeight
        } else {
            self.weightUnit = .kg
        }

        if let data = userDefaults.data(forKey: Keys.featureFlags),
           let decodedFlags = try? JSONDecoder().decode(FeatureFlags.self, from: data) {
            self.featureFlags = decodedFlags
        } else {
            self.featureFlags = FeatureFlags()
        }

        self.autoPauseEnabled = userDefaults.object(forKey: Keys.autoPauseEnabled) as? Bool ?? true
        self.audioCuesEnabled = userDefaults.object(forKey: Keys.audioCuesEnabled) as? Bool ?? true
        self.hapticsEnabled = userDefaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true

        let storedAcc = userDefaults.double(forKey: Keys.maxHorizontalAccuracyMeters)
        self.maxHorizontalAccuracyMeters = storedAcc > 0 ? storedAcc : 30.0

        let storedHyst = userDefaults.double(forKey: Keys.elevationHysteresisMeters)
        self.elevationHysteresisMeters = storedHyst > 0 ? storedHyst : 3.0

        let storedWeight = userDefaults.double(forKey: Keys.userWeightKg)
        self.userWeightKg = storedWeight > 0 ? storedWeight : 70.0

        let storedPrivacy = userDefaults.double(forKey: Keys.privacyHideRadiusMeters)
        self.privacyHideRadiusMeters = storedPrivacy > 0 ? storedPrivacy : 200.0

        self.lastBackupDate = userDefaults.object(forKey: Keys.lastBackupDate) as? Date

        self.keepScreenAwakeWhileRecording = userDefaults.object(forKey: Keys.keepScreenAwakeWhileRecording) as? Bool ?? false
        self.keepScreenAwakeDuringWorkout = userDefaults.object(forKey: Keys.keepScreenAwakeDuringWorkout) as? Bool ?? false
        self.selectedVoiceIdentifier = userDefaults.string(forKey: Keys.selectedVoiceIdentifier)

        let storedRate = userDefaults.object(forKey: Keys.speechRate) as? Float
        self.speechRate = storedRate ?? 0.47

        let storedPitch = userDefaults.object(forKey: Keys.speechPitch) as? Float
        self.speechPitch = storedPitch ?? 1.0

        let storedVolume = userDefaults.object(forKey: Keys.speechVolume) as? Float
        self.speechVolume = storedVolume ?? 0.95

        self.cueEveryUnitEnabled = userDefaults.object(forKey: Keys.cueEveryUnitEnabled) as? Bool ?? true
        self.cueEveryNMinutes = userDefaults.object(forKey: Keys.cueEveryNMinutes) as? Int ?? 0
        self.cueOnLapEnabled = userDefaults.object(forKey: Keys.cueOnLapEnabled) as? Bool ?? true
        self.cueOnPauseResumeEnabled = userDefaults.object(forKey: Keys.cueOnPauseResumeEnabled) as? Bool ?? true
        self.cueOnGoalReachedEnabled = userDefaults.object(forKey: Keys.cueOnGoalReachedEnabled) as? Bool ?? true

        let storedRest = userDefaults.object(forKey: Keys.defaultRestSeconds) as? Int
        self.defaultRestSeconds = (storedRest ?? 0) > 0 ? storedRest! : 90
    }

    func daysSinceLastBackup(now: Date = Date()) -> Int? {
        guard let lastBackupDate else { return nil }
        return max(0, Int(now.timeIntervalSince(lastBackupDate) / 86_400.0))
    }

    func needsBackupReminder(activityCount: Int, now: Date = Date()) -> Bool {
        guard activityCount > 0 else { return false }
        guard let lastBackupDate else { return true }
        return now.timeIntervalSince(lastBackupDate) >= 5.0 * 86_400.0
    }
}
