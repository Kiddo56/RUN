import Foundation

public enum UnitSystem: String, CaseIterable, Codable, Sendable, Identifiable {
    case metric
    case imperial

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .metric: return "Metric (km, m)"
        case .imperial: return "Imperial (mi, ft)"
        }
    }

    public var distanceUnitLabel: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }

    public var paceUnitLabel: String {
        switch self {
        case .metric: return "/km"
        case .imperial: return "/mi"
        }
    }

    public var speedUnitLabel: String {
        switch self {
        case .metric: return "km/h"
        case .imperial: return "mph"
        }
    }

    public var elevationUnitLabel: String {
        switch self {
        case .metric: return "m"
        case .imperial: return "ft"
        }
    }

    public var metersPerMajorUnit: Double {
        switch self {
        case .metric: return 1000.0
        case .imperial: return 1609.344
        }
    }
}

public enum WeightUnit: String, CaseIterable, Codable, Sendable, Identifiable {
    case kg
    case lb

    public static let poundsPerKilogram: Double = 2.20462262185

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .kg: return "Kilograms (kg)"
        case .lb: return "Pounds (lb)"
        }
    }

    public var symbol: String { rawValue }

    public func fromKilograms(_ kg: Double) -> Double {
        guard kg.isFinite else { return 0 }
        switch self {
        case .kg: return kg
        case .lb: return kg * Self.poundsPerKilogram
        }
    }

    public func toKilograms(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        switch self {
        case .kg: return value
        case .lb: return value / Self.poundsPerKilogram
        }
    }
}

public enum RunFormatter {
    public static func distanceValue(meters: Double, unit: UnitSystem) -> Double {
        guard meters.isFinite, meters >= 0 else { return 0 }
        return meters / unit.metersPerMajorUnit
    }

    public static func distance(meters: Double, unit: UnitSystem, decimals: Int = 2) -> String {
        let value = distanceValue(meters: meters, unit: unit)
        return String(format: "%.\(max(0, decimals))f %@", value, unit.distanceUnitLabel)
    }

    public static func pace(secondsPerMeter: Double, unit: UnitSystem) -> String {
        guard secondsPerMeter.isFinite, secondsPerMeter > 0 else {
            return "--:-- \(unit.paceUnitLabel)"
        }
        let secPerUnit = secondsPerMeter * unit.metersPerMajorUnit
        // Cap absurdly slow pace (> 99:59)
        guard secPerUnit.isFinite, secPerUnit < 6000.0 else {
            return "--:-- \(unit.paceUnitLabel)"
        }
        let totalSeconds = Int(secPerUnit.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d %@", minutes, seconds, unit.paceUnitLabel)
    }

    public static func speed(metersPerSecond: Double, unit: UnitSystem) -> String {
        guard metersPerSecond.isFinite, metersPerSecond >= 0 else {
            return String(format: "0.0 %@", unit.speedUnitLabel)
        }
        let value: Double
        switch unit {
        case .metric:
            value = metersPerSecond * 3.6
        case .imperial:
            value = metersPerSecond * 2.2369362920544
        }
        return String(format: "%.1f %@", value, unit.speedUnitLabel)
    }

    public static func elevation(meters: Double, unit: UnitSystem) -> String {
        guard meters.isFinite else { return "0 \(unit.elevationUnitLabel)" }
        let value: Double
        switch unit {
        case .metric:
            value = meters
        case .imperial:
            value = meters * 3.2808398950131
        }
        return "\(Int(value.rounded())) \(unit.elevationUnitLabel)"
    }

    public static func duration(seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    public static func weight(kg: Double, unit: WeightUnit) -> String {
        let val = unit.fromKilograms(max(0, kg))
        if abs(val - val.rounded()) < 0.05 {
            return String(format: "%.0f %@", val.rounded(), unit.symbol)
        }
        return String(format: "%.1f %@", val, unit.symbol)
    }

    public static func volume(kg: Double, unit: WeightUnit) -> String {
        let val = unit.fromKilograms(max(0, kg))
        if val >= 1000 {
            return String(format: "%.1fk %@", val / 1000.0, unit.symbol)
        }
        return String(format: "%.0f %@", val.rounded(), unit.symbol)
    }
}
