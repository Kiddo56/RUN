import Foundation

public enum RecordCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case fastest1K
    case fastest1Mi
    case fastest5K
    case fastest10K
    case fastestHalfMarathon
    case fastestFullMarathon
    case longestDistance
    case biggestClimb

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fastest1K: return "Fastest 1 km"
        case .fastest1Mi: return "Fastest 1 mi"
        case .fastest5K: return "Fastest 5 km"
        case .fastest10K: return "Fastest 10 km"
        case .fastestHalfMarathon: return "Half Marathon (21.1 km)"
        case .fastestFullMarathon: return "Marathon (42.2 km)"
        case .longestDistance: return "Longest Distance"
        case .biggestClimb: return "Biggest Climb"
        }
    }

    public var targetDistanceMeters: Double? {
        switch self {
        case .fastest1K: return 1_000.0
        case .fastest1Mi: return 1_609.344
        case .fastest5K: return 5_000.0
        case .fastest10K: return 10_000.0
        case .fastestHalfMarathon: return 21_097.5
        case .fastestFullMarathon: return 42_195.0
        case .longestDistance, .biggestClimb: return nil
        }
    }

    public var isTimeBased: Bool {
        targetDistanceMeters != nil
    }
}

public struct PersonalRecord: Identifiable, Codable, Sendable, Equatable {
    public let category: RecordCategory
    public let activityID: UUID
    public let activityTitle: String
    public let activityType: ActivityType
    public let date: Date
    public let value: Double

    public var id: RecordCategory { category }
}

public enum PersonalRecordScanner {
    /// Two-pointer sliding window returning the fastest elapsed duration covering `target` meters.
    public static func fastestDuration(
        forTargetMeters target: Double,
        in points: [TrackPoint]
    ) -> TimeInterval? {
        guard target > 0, points.count >= 2 else { return nil }

        var cumDist: [Double] = [0.0]
        cumDist.reserveCapacity(points.count)
        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            let step = (p0.isPaused && p1.isPaused) ? 0.0 : GeoMath.distanceMeters(from: p0, to: p1)
            cumDist.append(cumDist[i - 1] + step)
        }

        guard let total = cumDist.last, total >= target else { return nil }

        var bestDuration: TimeInterval?
        var left = 0

        for right in 1..<points.count {
            while left < right && (cumDist[right] - cumDist[left]) >= target {
                let segDist = cumDist[right] - cumDist[right - 1]
                let segDt = max(0.0, points[right].timestamp.timeIntervalSince(points[right - 1].timestamp))

                let crossTime: Date
                if segDist > 0.01 {
                    let needed = (cumDist[left] + target) - cumDist[right - 1]
                    let fraction = min(1.0, max(0.0, needed / segDist))
                    crossTime = points[right - 1].timestamp.addingTimeInterval(fraction * segDt)
                } else {
                    crossTime = points[right].timestamp
                }

                let duration = crossTime.timeIntervalSince(points[left].timestamp)
                if duration > 0 {
                    if let currentBest = bestDuration {
                        if duration < currentBest { bestDuration = duration }
                    } else {
                        bestDuration = duration
                    }
                }
                left += 1
            }
        }

        return bestDuration
    }

    public static func scanAll(
        activities: [(input: ActivityStatsInput, points: [TrackPoint])]
    ) -> [PersonalRecord] {
        var bestByCategory: [RecordCategory: PersonalRecord] = [:]

        for entry in activities {
            let meta = entry.input
            let pts = entry.points

            if meta.distanceMeters > 0 {
                let candidate = PersonalRecord(
                    category: .longestDistance,
                    activityID: meta.id,
                    activityTitle: meta.title,
                    activityType: meta.activityType,
                    date: meta.startDate,
                    value: meta.distanceMeters
                )
                if let existing = bestByCategory[.longestDistance] {
                    if candidate.value > existing.value { bestByCategory[.longestDistance] = candidate }
                } else {
                    bestByCategory[.longestDistance] = candidate
                }
            }

            if meta.elevationGainMeters > 0 {
                let candidate = PersonalRecord(
                    category: .biggestClimb,
                    activityID: meta.id,
                    activityTitle: meta.title,
                    activityType: meta.activityType,
                    date: meta.startDate,
                    value: meta.elevationGainMeters
                )
                if let existing = bestByCategory[.biggestClimb] {
                    if candidate.value > existing.value { bestByCategory[.biggestClimb] = candidate }
                } else {
                    bestByCategory[.biggestClimb] = candidate
                }
            }

            for cat in RecordCategory.allCases {
                guard let target = cat.targetDistanceMeters,
                      meta.distanceMeters >= target * 0.98,
                      let bestTime = fastestDuration(forTargetMeters: target, in: pts) else {
                    continue
                }
                let candidate = PersonalRecord(
                    category: cat,
                    activityID: meta.id,
                    activityTitle: meta.title,
                    activityType: meta.activityType,
                    date: meta.startDate,
                    value: bestTime
                )
                if let existing = bestByCategory[cat] {
                    if candidate.value < existing.value { bestByCategory[cat] = candidate }
                } else {
                    bestByCategory[cat] = candidate
                }
            }
        }

        return RecordCategory.allCases.compactMap { bestByCategory[$0] }
    }
}
