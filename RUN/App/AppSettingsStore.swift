import Foundation
import Observation
import TrackerCore

@MainActor
@Observable
final class AppSettingsStore {
    private enum Keys {
        static let unitSystem = "run.settings.unitSystem"
        static let featureFlags = "run.settings.featureFlags"
        static let autoPauseEnabled = "run.settings.autoPauseEnabled"
        static let audioCuesEnabled = "run.settings.audioCuesEnabled"
        static let hapticsEnabled = "run.settings.hapticsEnabled"
        static let maxHorizontalAccuracyMeters = "run.settings.maxHorizontalAccuracyMeters"
        static let elevationHysteresisMeters = "run.settings.elevationHysteresisMeters"
        static let userWeightKg = "run.settings.userWeightKg"
        static let privacyHideRadiusMeters = "run.settings.privacyHideRadiusMeters"
        static let lastBackupDate = "run.settings.lastBackupDate"
    }

    private let defaults: UserDefaults

    var unitSystem: UnitSystem {
        didSet { defaults.set(unitSystem.rawValue, forKey: Keys.unitSystem) }
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

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults

        if let rawUnit = userDefaults.string(forKey: Keys.unitSystem),
           let parsedUnit = UnitSystem(rawValue: rawUnit) {
            self.unitSystem = parsedUnit
        } else {
            self.unitSystem = .metric
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
