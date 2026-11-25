import Foundation

public struct FeatureFlags: Codable, Sendable, Equatable {
    public var bleHeartRate: Bool
    public var barometricAltimeter: Bool
    public var personalSections: Bool
    public var personalHeatmap: Bool

    public init(
        bleHeartRate: Bool = false,
        barometricAltimeter: Bool = false,
        personalSections: Bool = false,
        personalHeatmap: Bool = false
    ) {
        self.bleHeartRate = bleHeartRate
        self.barometricAltimeter = barometricAltimeter
        self.personalSections = personalSections
        self.personalHeatmap = personalHeatmap
    }
}
