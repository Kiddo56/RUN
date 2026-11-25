import Foundation

public enum GPSQuality: String, Codable, Sendable, Equatable {
    case excellent
    case good
    case fair
    case poor
    case lost

    public var displayName: String {
        switch self {
        case .excellent: return "Strong"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Weak"
        case .lost: return "No Signal"
        }
    }
}

public enum GPSRejectReason: String, Codable, Sendable, Equatable {
    case invalidAccuracy
    case accuracyTooLow
    case staleTimestamp
    case nonMonotonicTimestamp
    case impossibleSpeedJump
    case stationaryJitter
}

public enum GPSFilterDecision: Sendable, Equatable {
    case accept(distanceDeltaMeters: Double, computedSpeedMPS: Double, quality: GPSQuality)
    case reject(reason: GPSRejectReason, quality: GPSQuality)
}

public struct GPSFilterConfig: Codable, Sendable, Equatable {
    public var maxHorizontalAccuracyMeters: Double
    public var maxStaleAgeSeconds: TimeInterval
    public var minDistanceJitterMeters: Double
    public var maxPlausibleSpeedMPS: Double

    public init(
        maxHorizontalAccuracyMeters: Double = 30.0,
        maxStaleAgeSeconds: TimeInterval = 15.0,
        minDistanceJitterMeters: Double = 1.5,
        maxPlausibleSpeedMPS: Double = 12.0
    ) {
        self.maxHorizontalAccuracyMeters = maxHorizontalAccuracyMeters
        self.maxStaleAgeSeconds = maxStaleAgeSeconds
        self.minDistanceJitterMeters = minDistanceJitterMeters
        self.maxPlausibleSpeedMPS = maxPlausibleSpeedMPS
    }
}

public struct GPSFilter: Sendable {
    public let sessionStart: Date
    public var config: GPSFilterConfig
    public private(set) var lastAcceptedPoint: TrackPoint?

    public init(
        sessionStart: Date,
        config: GPSFilterConfig = GPSFilterConfig(),
        lastAcceptedPoint: TrackPoint? = nil
    ) {
        self.sessionStart = sessionStart
        self.config = config
        self.lastAcceptedPoint = lastAcceptedPoint
    }

    public static func classifyQuality(horizontalAccuracy: Double) -> GPSQuality {
        guard horizontalAccuracy.isFinite, horizontalAccuracy >= 0 else {
            return .lost
        }
        if horizontalAccuracy <= 8.0 { return .excellent }
        if horizontalAccuracy <= 15.0 { return .good }
        if horizontalAccuracy <= 30.0 { return .fair }
        return .poor
    }

    public mutating func resetContinuity() {
        lastAcceptedPoint = nil
    }

    public mutating func evaluate(_ point: TrackPoint, referenceNow: Date) -> GPSFilterDecision {
        let quality = Self.classifyQuality(horizontalAccuracy: point.horizontalAccuracy)

        guard point.latitude.isFinite, point.longitude.isFinite,
              point.horizontalAccuracy.isFinite, point.horizontalAccuracy >= 0 else {
            return .reject(reason: .invalidAccuracy, quality: .lost)
        }

        guard point.horizontalAccuracy <= config.maxHorizontalAccuracyMeters else {
            return .reject(reason: .accuracyTooLow, quality: quality)
        }

        let age = referenceNow.timeIntervalSince(point.timestamp)
        if age > config.maxStaleAgeSeconds || point.timestamp < sessionStart.addingTimeInterval(-2.0) {
            return .reject(reason: .staleTimestamp, quality: .lost)
        }

        guard let previous = lastAcceptedPoint else {
            lastAcceptedPoint = point
            let speed = (point.speed.isFinite && point.speed >= 0) ? point.speed : 0
            return .accept(distanceDeltaMeters: 0, computedSpeedMPS: speed, quality: quality)
        }

        let dt = point.timestamp.timeIntervalSince(previous.timestamp)
        guard dt > 0 else {
            return .reject(reason: .nonMonotonicTimestamp, quality: quality)
        }

        let delta = GeoMath.distanceMeters(from: previous, to: point)
        let computedSpeed = delta / dt

        if computedSpeed > config.maxPlausibleSpeedMPS && delta > 25.0 {
            return .reject(reason: .impossibleSpeedJump, quality: quality)
        }

        if delta < config.minDistanceJitterMeters && point.speed >= 0 && point.speed < 0.3 {
            return .reject(reason: .stationaryJitter, quality: quality)
        }

        lastAcceptedPoint = point
        return .accept(distanceDeltaMeters: delta, computedSpeedMPS: computedSpeed, quality: quality)
    }
}
