import Foundation

public struct ElevationEngine: Sendable {
    public let hysteresisMeters: Double
    public let maxVerticalAccuracyMeters: Double

    public private(set) var anchorAltitudeMeters: Double?
    public private(set) var currentAltitudeMeters: Double?
    public private(set) var elevationGainMeters: Double = 0
    public private(set) var elevationLossMeters: Double = 0

    public init(hysteresisMeters: Double = 3.0, maxVerticalAccuracyMeters: Double = 50.0) {
        self.hysteresisMeters = max(0.5, hysteresisMeters)
        self.maxVerticalAccuracyMeters = max(1.0, maxVerticalAccuracyMeters)
    }

    public mutating func ingest(altitudeMeters: Double, verticalAccuracy: Double = 10.0) {
        guard altitudeMeters.isFinite else { return }
        if verticalAccuracy.isFinite, verticalAccuracy < 0 || verticalAccuracy > maxVerticalAccuracyMeters {
            return
        }

        currentAltitudeMeters = altitudeMeters
        guard let anchor = anchorAltitudeMeters else {
            anchorAltitudeMeters = altitudeMeters
            return
        }

        let delta = altitudeMeters - anchor
        if delta >= hysteresisMeters {
            elevationGainMeters += delta
            anchorAltitudeMeters = altitudeMeters
        } else if delta <= -hysteresisMeters {
            elevationLossMeters += abs(delta)
            anchorAltitudeMeters = altitudeMeters
        }
    }
}
