import Foundation

public enum SplitCalculator {
    public static func computeSplits(
        points: [TrackPoint],
        unitSystem: UnitSystem,
        movingThresholdMPS: Double = 0.4,
        elevationHysteresisMeters: Double = 3.0
    ) -> [ActivitySplit] {
        guard points.count >= 2 else { return [] }

        let targetMeters = unitSystem.metersPerMajorUnit
        var splits: [ActivitySplit] = []

        var splitIndex = 1
        var splitDistance = 0.0
        var splitDuration: TimeInterval = 0
        var splitMoving: TimeInterval = 0
        var splitHRWeighted = 0.0
        var splitHRWeight = 0.0

        var elevEngine = ElevationEngine(hysteresisMeters: elevationHysteresisMeters)
        var splitStartGain = 0.0
        var splitStartLoss = 0.0
        elevEngine.ingest(altitudeMeters: points[0].altitude, verticalAccuracy: points[0].verticalAccuracy)

        for idx in 1..<points.count {
            let p0 = points[idx - 1]
            let p1 = points[idx]
            elevEngine.ingest(altitudeMeters: p1.altitude, verticalAccuracy: p1.verticalAccuracy)

            let rawDt = max(0, p1.timestamp.timeIntervalSince(p0.timestamp))
            if p0.isPaused && p1.isPaused {
                continue
            }

            let segDist = GeoMath.distanceMeters(from: p0, to: p1)
            guard segDist > 0 || rawDt > 0 else { continue }

            let segSpeed = rawDt > 0 ? (segDist / rawDt) : 0
            let isMoving = !p0.isPaused && !p1.isPaused && segSpeed >= movingThresholdMPS

            var remainingDist = segDist
            var remainingDuration = rawDt
            var remainingMoving = isMoving ? rawDt : 0

            while splitDistance + remainingDist >= targetMeters && remainingDist > 0 {
                let needed = targetMeters - splitDistance
                let fraction = min(1.0, max(0.0, needed / remainingDist))

                let durPart = remainingDuration * fraction
                let movPart = remainingMoving * fraction

                splitDistance += needed
                splitDuration += durPart
                splitMoving += movPart

                if let hr = p1.heartRate ?? p0.heartRate, hr > 0 {
                    splitHRWeighted += hr * max(0.1, durPart)
                    splitHRWeight += max(0.1, durPart)
                }

                let gain = max(0, elevEngine.elevationGainMeters - splitStartGain)
                let loss = max(0, elevEngine.elevationLossMeters - splitStartLoss)
                splitStartGain = elevEngine.elevationGainMeters
                splitStartLoss = elevEngine.elevationLossMeters

                splits.append(
                    ActivitySplit(
                        index: splitIndex,
                        distanceMeters: targetMeters,
                        durationSeconds: splitDuration,
                        movingSeconds: splitMoving,
                        elevationGainMeters: gain,
                        elevationLossMeters: loss,
                        averageHeartRate: splitHRWeight > 0 ? (splitHRWeighted / splitHRWeight) : nil,
                        isPartial: false
                    )
                )

                splitIndex += 1
                splitDistance = 0
                splitDuration = 0
                splitMoving = 0
                splitHRWeighted = 0
                splitHRWeight = 0

                remainingDist -= needed
                remainingDuration -= durPart
                remainingMoving -= movPart
            }

            splitDistance += remainingDist
            splitDuration += remainingDuration
            splitMoving += remainingMoving

            if let hr = p1.heartRate ?? p0.heartRate, hr > 0 {
                splitHRWeighted += hr * max(0.1, remainingDuration)
                splitHRWeight += max(0.1, remainingDuration)
            }
        }

        if splitDistance > 10.0 {
            let gain = max(0, elevEngine.elevationGainMeters - splitStartGain)
            let loss = max(0, elevEngine.elevationLossMeters - splitStartLoss)
            splits.append(
                ActivitySplit(
                    index: splitIndex,
                    distanceMeters: splitDistance,
                    durationSeconds: splitDuration,
                    movingSeconds: splitMoving,
                    elevationGainMeters: gain,
                    elevationLossMeters: loss,
                    averageHeartRate: splitHRWeight > 0 ? (splitHRWeighted / splitHRWeight) : nil,
                    isPartial: true
                )
            )
        }

        return splits
    }
}

public struct LiveSplitTracker: Sendable {
    public let splitDistanceMeters: Double
    private var completedSplitCount: Int = 0
    private var lastSplitElapsed: TimeInterval = 0
    private var lastSplitMoving: TimeInterval = 0
    private var lastSplitGain: Double = 0
    private var lastSplitLoss: Double = 0

    public init(unitSystem: UnitSystem) {
        self.splitDistanceMeters = unitSystem.metersPerMajorUnit
    }

    public mutating func checkForNewSplit(
        totalDistanceMeters: Double,
        elapsedTime: TimeInterval,
        movingTime: TimeInterval,
        elevationGainMeters: Double,
        elevationLossMeters: Double
    ) -> ActivitySplit? {
        let nextBoundary = Double(completedSplitCount + 1) * splitDistanceMeters
        guard totalDistanceMeters >= nextBoundary else { return nil }

        completedSplitCount += 1
        let dur = max(0, elapsedTime - lastSplitElapsed)
        let mov = max(0, movingTime - lastSplitMoving)
        let gain = max(0, elevationGainMeters - lastSplitGain)
        let loss = max(0, elevationLossMeters - lastSplitLoss)

        lastSplitElapsed = elapsedTime
        lastSplitMoving = movingTime
        lastSplitGain = elevationGainMeters
        lastSplitLoss = elevationLossMeters

        return ActivitySplit(
            index: completedSplitCount,
            distanceMeters: splitDistanceMeters,
            durationSeconds: dur,
            movingSeconds: mov,
            elevationGainMeters: gain,
            elevationLossMeters: loss,
            isPartial: false
        )
    }
}
