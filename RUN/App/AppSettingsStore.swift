import Foundation
import Observation
import TrackerCore

@MainActor
@Observable
final class AppSettingsStore {
    private enum Keys {
        static let unitSystem = "run.settings.unitSystem"
        static let featureFlags = "run.settings.featureFlags"
    }

    private let defaults: UserDefaults

    var unitSystem: UnitSystem {
        didSet {
            defaults.set(unitSystem.rawValue, forKey: Keys.unitSystem)
        }
    }

    var featureFlags: FeatureFlags {
        didSet {
            if let data = try? JSONEncoder().encode(featureFlags) {
                defaults.set(data, forKey: Keys.featureFlags)
            }
        }
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
    }
}
