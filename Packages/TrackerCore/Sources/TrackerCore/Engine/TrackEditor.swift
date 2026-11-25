import Foundation

public struct TrackEditResult: Sendable, Equatable {
    public let points: [TrackPoint]
    public let summary: ActivityMetricsSummary

    public init(points: [TrackPoint], summary: ActivityMetricsSummary) {
        self.points = points
        self.summary = summary
    }
}

public enum TrackEditor {
    public static func trim(
        points: [TrackPoint],
        startIndex: Int,
        endIndex: Int,
        activityType: ActivityType,
        unitSystem: UnitSystem,
        userWeightKg: Double = 70.0,
        elevationHysteresisMeters: Double = 3.0
    ) -> TrackEditResult? {
        guard points.count >= 2,
              startIndex >= 0,
              endIndex < points.count,
              endIndex - startIndex >= 1 else {
            return nil
        }

        let sliced = Array(points[startIndex...endIndex])
        let summary = TrackAnalyzer.summarize(
            points: sliced,
            activityType: activityType,
            unitSystem: unitSystem,
            userWeightKg: userWeightKg,
            elevationHysteresisMeters: elevationHysteresisMeters
        )
        return TrackEditResult(points: sliced, summary: summary)
    }

    public static func merge(
        first: [TrackPoint],
        second: [TrackPoint],
        activityType: ActivityType,
        unitSystem: UnitSystem,
        userWeightKg: Double = 70.0,
        elevationHysteresisMeters: Double = 3.0
    ) -> TrackEditResult? {
        guard !first.isEmpty, !second.isEmpty else { return nil }

        let firstSorted = first.sorted { $0.timestamp < $1.timestamp }
        let secondSorted = second.sorted { $0.timestamp < $1.timestamp }

        let earlier: [TrackPoint]
        let later: [TrackPoint]
        if firstSorted[0].timestamp <= secondSorted[0].timestamp {
            earlier = firstSorted
            later = secondSorted
        } else {
            earlier = secondSorted
            later = firstSorted
        }

        var combined: [TrackPoint] = earlier
        if let endEarlier = earlier.last, let startLater = later.first {
            let gap = startLater.timestamp.timeIntervalSince(endEarlier.timestamp)
            if gap > 30.0 {
                var bridgeStart = endEarlier
                bridgeStart.timestamp = endEarlier.timestamp.addingTimeInterval(0.5)
                bridgeStart.speed = 0
                bridgeStart.isPaused = true

                var bridgeEnd = startLater
                bridgeEnd.timestamp = startLater.timestamp.addingTimeInterval(-0.5)
                bridgeEnd.speed = 0
                bridgeEnd.isPaused = true

                combined.append(bridgeStart)
                if bridgeEnd.timestamp > bridgeStart.timestamp {
                    combined.append(bridgeEnd)
                }
            }
        }

        for pt in later {
            if let last = combined.last, pt.timestamp <= last.timestamp {
                continue
            }
            combined.append(pt)
        }

        guard combined.count >= 2 else { return nil }
        let summary = TrackAnalyzer.summarize(
            points: combined,
            activityType: activityType,
            unitSystem: unitSystem,
            userWeightKg: userWeightKg,
            elevationHysteresisMeters: elevationHysteresisMeters
        )
        return TrackEditResult(points: combined, summary: summary)
    }
}
