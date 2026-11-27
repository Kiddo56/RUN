import Foundation

public enum ActivityType: String, CaseIterable, Codable, Sendable, Identifiable {
    case run
    case ride
    case walk
    case hike
    case strength
    case other

    public static var gpsCases: [ActivityType] {
        [.run, .ride, .walk, .hike, .other]
    }

    public var id: String { rawValue }

    public var isGPSActivity: Bool {
        self != .strength
    }

    public var displayName: String {
        switch self {
        case .run: return "Run"
        case .ride: return "Ride"
        case .walk: return "Walk"
        case .hike: return "Hike"
        case .strength: return "Strength"
        case .other: return "Other"
        }
    }

    public var prefersSpeedOverPace: Bool {
        self == .ride
    }

    public var defaultAutoPauseSpeedMPS: Double {
        switch self {
        case .run: return 0.8
        case .ride: return 1.5
        case .walk: return 0.4
        case .hike: return 0.4
        case .strength: return 0.0
        case .other: return 0.5
        }
    }

    public var maxPlausibleSpeedMPS: Double {
        switch self {
        case .run: return 12.0
        case .ride: return 35.0
        case .walk: return 6.0
        case .hike: return 8.0
        case .strength: return 5.0
        case .other: return 35.0
        }
    }

    public var symbolName: String {
        switch self {
        case .run: return "figure.run"
        case .ride: return "bicycle"
        case .walk: return "figure.walk"
        case .hike: return "figure.hiking"
        case .strength: return "dumbbell.fill"
        case .other: return "location.north.line"
        }
    }
}
