import Foundation

public struct SectionSpec: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let activityType: ActivityType
    public let startLatitude: Double
    public let startLongitude: Double
    public let endLatitude: Double
    public let endLongitude: Double
    public let expectedBearing: Double
    public let distanceMeters: Double
    public let corridorMeters: Double

    public init(
        id: UUID,
        name: String,
        activityType: ActivityType,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double,
        expectedBearing: Double,
        distanceMeters: Double,
        corridorMeters: Double = 35.0
    ) {
        self.id = id
        self.name = name
        self.activityType = activityType
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.expectedBearing = expectedBearing
        self.distanceMeters = distanceMeters
        self.corridorMeters = corridorMeters
    }
}

public struct SectionAttempt: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let sectionID: UUID
    public let activityID: UUID
    public let activityTitle: String
    public let date: Date
    public let durationSeconds: TimeInterval
    public let distanceMeters: Double
    public let paceSecondsPerMeter: Double
    public let speedMPS: Double

    public init(
        id: UUID,
        sectionID: UUID,
        activityID: UUID,
        activityTitle: String,
        date: Date,
        durationSeconds: TimeInterval,
        distanceMeters: Double,
        paceSecondsPerMeter: Double,
        speedMPS: Double
    ) {
        self.id = id
        self.sectionID = sectionID
        self.activityID = activityID
        self.activityTitle = activityTitle
        self.date = date
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.paceSecondsPerMeter = paceSecondsPerMeter
        self.speedMPS = speedMPS
    }
}

public enum SectionMatcher {
    public static func findAttempts(
        section: SectionSpec,
        activityID: UUID,
        activityTitle: String,
        activityType: ActivityType,
        points: [TrackPoint]
    ) -> [SectionAttempt] {
        guard activityType == section.activityType,
              points.count >= 2,
              section.distanceMeters >= 20.0,
              section.corridorMeters > 0 else {
            return []
        }

        var cumDist: [Double] = Array(repeating: 0.0, count: points.count)
        for i in 1..<points.count {
            cumDist[i] = cumDist[i - 1] + GeoMath.distanceMeters(from: points[i - 1], to: points[i])
        }

        var attempts: [SectionAttempt] = []
        var idx = 0

        while idx < points.count - 1 {
            let dStart = GeoMath.distanceMeters(
                lat1: points[idx].latitude,
                lon1: points[idx].longitude,
                lat2: section.startLatitude,
                lon2: section.startLongitude
            )

            guard dStart <= section.corridorMeters else {
                idx += 1
                continue
            }

            var bestStartIdx = idx
            var bestStartDist = dStart
            var gateExitIdx = idx + 1
            while gateExitIdx < points.count {
                let dGate = GeoMath.distanceMeters(
                    lat1: points[gateExitIdx].latitude,
                    lon1: points[gateExitIdx].longitude,
                    lat2: section.startLatitude,
                    lon2: section.startLongitude
                )
                if dGate > section.corridorMeters { break }
                if dGate < bestStartDist {
                    bestStartDist = dGate
                    bestStartIdx = gateExitIdx
                }
                gateExitIdx += 1
            }

            guard bestStartIdx < points.count - 1 else { break }

            // Verify forward movement direction using a short lookahead along the track.
            var lookaheadIdx = min(points.count - 1, bestStartIdx + 1)
            let maxLookaheadIdx = min(points.count - 1, bestStartIdx + 3)
            while lookaheadIdx < maxLookaheadIdx {
                let dLook = GeoMath.distanceMeters(from: points[bestStartIdx], to: points[lookaheadIdx])
                if dLook >= 5.0 { break }
                lookaheadIdx += 1
            }
            if GeoMath.distanceMeters(from: points[bestStartIdx], to: points[lookaheadIdx]) < 1.0 {
                while lookaheadIdx < points.count - 1 &&
                        GeoMath.distanceMeters(from: points[bestStartIdx], to: points[lookaheadIdx]) < 5.0 {
                    lookaheadIdx += 1
                }
            }

            guard GeoMath.distanceMeters(from: points[bestStartIdx], to: points[lookaheadIdx]) >= 1.0 else {
                idx = gateExitIdx
                continue
            }

            let travelBearing = GeoMath.bearingDegrees(
                lat1: points[bestStartIdx].latitude,
                lon1: points[bestStartIdx].longitude,
                lat2: points[lookaheadIdx].latitude,
                lon2: points[lookaheadIdx].longitude
            )
            guard GeoMath.angleDifferenceDegrees(travelBearing, section.expectedBearing) <= 75.0 else {
                idx = gateExitIdx
                continue
            }

            // Scan forward for end gate crossing.
            var j = bestStartIdx + 1
            var matchedAttempt: SectionAttempt?
            var nextIndexAfterAttempt = gateExitIdx

            while j < points.count {
                let dEnd = GeoMath.distanceMeters(
                    lat1: points[j].latitude,
                    lon1: points[j].longitude,
                    lat2: section.endLatitude,
                    lon2: section.endLongitude
                )
                if dEnd <= section.corridorMeters {
                    var bestEndIdx = j
                    var bestEndDist = dEnd
                    var k = j + 1
                    while k < points.count {
                        let dk = GeoMath.distanceMeters(
                            lat1: points[k].latitude,
                            lon1: points[k].longitude,
                            lat2: section.endLatitude,
                            lon2: section.endLongitude
                        )
                        if dk > section.corridorMeters { break }
                        if dk < bestEndDist {
                            bestEndDist = dk
                            bestEndIdx = k
                        }
                        k += 1
                    }

                    let duration = points[bestEndIdx].timestamp.timeIntervalSince(points[bestStartIdx].timestamp)
                    let traversed = cumDist[bestEndIdx] - cumDist[bestStartIdx]
                    let minDist = section.distanceMeters * 0.7
                    let maxDist = max(section.distanceMeters * 2.5, section.distanceMeters + 250.0)

                    if duration > 0, traversed >= minDist, traversed <= maxDist {
                        matchedAttempt = SectionAttempt(
                            id: UUID(),
                            sectionID: section.id,
                            activityID: activityID,
                            activityTitle: activityTitle,
                            date: points[bestStartIdx].timestamp,
                            durationSeconds: duration,
                            distanceMeters: traversed,
                            paceSecondsPerMeter: duration / max(1.0, traversed),
                            speedMPS: traversed / duration
                        )
                        nextIndexAfterAttempt = max(bestEndIdx + 1, k)
                        break
                    } else if traversed > maxDist {
                        break
                    } else {
                        j = k
                        continue
                    }
                }
                j += 1
            }

            if let attempt = matchedAttempt {
                attempts.append(attempt)
                idx = nextIndexAfterAttempt
            } else {
                idx = gateExitIdx
            }
        }

        return attempts
    }

    public static func rankAttempts(_ attempts: [SectionAttempt]) -> [SectionAttempt] {
        attempts.sorted { lhs, rhs in
            if abs(lhs.durationSeconds - rhs.durationSeconds) > 1e-6 {
                return lhs.durationSeconds < rhs.durationSeconds
            }
            return lhs.date < rhs.date
        }
    }
}
