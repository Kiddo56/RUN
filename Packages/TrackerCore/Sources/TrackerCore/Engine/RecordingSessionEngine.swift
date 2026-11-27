import Foundation

public struct LiveRecordingUpdate: Sendable, Equatable {
    public let decision: GPSFilterDecision
    public let movingTransition: MovingTransition
    public let completedSplit: ActivitySplit?
    public let quality: GPSQuality
}

public struct RecordingSessionEngine: Sendable {
    public let activityType: ActivityType
    public let unitSystem: UnitSystem
    public let startDate: Date
    public let userWeightKg: Double

    public private(set) var points: [TrackPoint] = []
    public private(set) var distanceMeters: Double = 0
    public private(set) var lastQuality: GPSQuality = .lost
    public private(set) var lastHorizontalAccuracyMeters: Double?
    public private(set) var lastSpeedMPS: Double = 0

    private var gpsFilter: GPSFilter
    private var paceSmoother: PaceSmoother
    private var movingEngine: MovingTimeEngine
    private var elevationEngine: ElevationEngine
    private var splitTracker: LiveSplitTracker

    public init(
        activityType: ActivityType,
        unitSystem: UnitSystem,
        startDate: Date,
        autoPauseEnabled: Bool = true,
        autoPauseSpeedThresholdMPS: Double? = nil,
        maxHorizontalAccuracyMeters: Double = 30.0,
        elevationHysteresisMeters: Double = 3.0,
        userWeightKg: Double = 70.0
    ) {
        self.activityType = activityType
        self.unitSystem = unitSystem
        self.startDate = startDate
        self.userWeightKg = max(30.0, userWeightKg)

        let filterConfig = GPSFilterConfig(
            maxHorizontalAccuracyMeters: maxHorizontalAccuracyMeters,
            maxStaleAgeSeconds: 15.0,
            minDistanceJitterMeters: 1.5,
            maxPlausibleSpeedMPS: activityType.maxPlausibleSpeedMPS
        )
        self.gpsFilter = GPSFilter(sessionStart: startDate, config: filterConfig)
        self.paceSmoother = PaceSmoother()
        self.movingEngine = MovingTimeEngine(
            autoPauseEnabled: autoPauseEnabled,
            autoPauseSpeedThresholdMPS: autoPauseSpeedThresholdMPS ?? activityType.defaultAutoPauseSpeedMPS
        )
        self.movingEngine.start(at: startDate)
        self.elevationEngine = ElevationEngine(hysteresisMeters: elevationHysteresisMeters)
        self.splitTracker = LiveSplitTracker(unitSystem: unitSystem)
    }

    public var elapsedTime: TimeInterval { movingEngine.elapsedTime }
    public var movingTime: TimeInterval { movingEngine.movingTime }
    public var elevationGainMeters: Double { elevationEngine.elevationGainMeters }
    public var elevationLossMeters: Double { elevationEngine.elevationLossMeters }
    public var isAutoPaused: Bool { movingEngine.isAutoPaused }
    public var isManuallyPaused: Bool { movingEngine.isManuallyPaused }

    public var currentSpeedMPS: Double {
        let smoothed = paceSmoother.smoothedSpeedMPS
        return smoothed > 0 ? smoothed : lastSpeedMPS
    }

    public var currentPaceSecondsPerMeter: Double {
        let smoothed = paceSmoother.smoothedPaceSecondsPerMeter
        if smoothed > 0 { return smoothed }
        guard lastSpeedMPS > 0.2 else { return 0 }
        return 1.0 / lastSpeedMPS
    }

    public var averageSpeedMPS: Double {
        guard movingTime > 0 else { return 0 }
        return distanceMeters / movingTime
    }

    public var averagePaceSecondsPerMeter: Double {
        guard distanceMeters > 0, movingTime > 0 else { return 0 }
        return movingTime / distanceMeters
    }

    public mutating func ingest(_ rawPoint: TrackPoint, now: Date) -> LiveRecordingUpdate {
        lastHorizontalAccuracyMeters = rawPoint.horizontalAccuracy >= 0 ? rawPoint.horizontalAccuracy : nil
        let decision = gpsFilter.evaluate(rawPoint, referenceNow: now)

        switch decision {
        case let .reject(_, quality):
            lastQuality = quality
            let transition = movingEngine.advance(to: now, speedMPS: nil)
            return LiveRecordingUpdate(
                decision: decision,
                movingTransition: transition,
                completedSplit: nil,
                quality: quality
            )

        case let .accept(deltaDist, computedSpeed, quality):
            lastQuality = quality
            let speedReading = (rawPoint.speed.isFinite && rawPoint.speed >= 0) ? rawPoint.speed : computedSpeed
            lastSpeedMPS = speedReading

            if isManuallyPaused {
                let transition = movingEngine.advance(to: rawPoint.timestamp, speedMPS: 0)
                var pausedPoint = rawPoint
                pausedPoint.isPaused = true
                points.append(pausedPoint)
                return LiveRecordingUpdate(
                    decision: decision,
                    movingTransition: transition,
                    completedSplit: nil,
                    quality: quality
                )
            }

            let transition = movingEngine.advance(to: rawPoint.timestamp, speedMPS: speedReading)
            if transition == .didAutoPause {
                paceSmoother.reset()
            }

            if !movingEngine.isAutoPaused {
                distanceMeters += deltaDist
                paceSmoother.append(timestamp: rawPoint.timestamp, cumulativeDistanceMeters: distanceMeters)
                elevationEngine.ingest(altitudeMeters: rawPoint.altitude, verticalAccuracy: rawPoint.verticalAccuracy)
            }

            var storedPoint = rawPoint
            storedPoint.isPaused = movingEngine.isAutoPaused
            points.append(storedPoint)

            let completedSplit = splitTracker.checkForNewSplit(
                totalDistanceMeters: distanceMeters,
                elapsedTime: movingEngine.elapsedTime,
                movingTime: movingEngine.movingTime,
                elevationGainMeters: elevationEngine.elevationGainMeters,
                elevationLossMeters: elevationEngine.elevationLossMeters
            )

            return LiveRecordingUpdate(
                decision: decision,
                movingTransition: transition,
                completedSplit: completedSplit,
                quality: quality
            )
        }
    }

    @discardableResult
    public mutating func tick(now: Date) -> MovingTransition {
        let transition = movingEngine.advance(to: now, speedMPS: nil)
        if transition == .didAutoPause {
            paceSmoother.reset()
        }
        return transition
    }

    public mutating func pauseManually(at date: Date) {
        movingEngine.pauseManually(at: date)
        paceSmoother.reset()
        gpsFilter.resetContinuity()
    }

    public mutating func resumeManually(at date: Date) {
        movingEngine.resumeManually(at: date)
        gpsFilter.resetContinuity()
    }

    public mutating func finish(at date: Date) -> ActivityMetricsSummary {
        _ = movingEngine.advance(to: date, speedMPS: nil)
        return TrackAnalyzer.summarize(
            points: points,
            activityType: activityType,
            unitSystem: unitSystem,
            userWeightKg: userWeightKg,
            elevationHysteresisMeters: elevationEngine.hysteresisMeters,
            overrideStartDate: startDate,
            overrideEndDate: date,
            overrideElapsedTime: movingEngine.elapsedTime,
            overrideMovingTime: movingEngine.movingTime,
            overrideDistance: distanceMeters,
            overrideElevationGain: elevationEngine.elevationGainMeters,
            overrideElevationLoss: elevationEngine.elevationLossMeters
        )
    }
}

public enum TrackAnalyzer {
    public static func summarize(
        points: [TrackPoint],
        activityType: ActivityType,
        unitSystem: UnitSystem = .metric,
        userWeightKg: Double = 70.0,
        elevationHysteresisMeters: Double = 3.0,
        overrideStartDate: Date? = nil,
        overrideEndDate: Date? = nil,
        overrideElapsedTime: TimeInterval? = nil,
        overrideMovingTime: TimeInterval? = nil,
        overrideDistance: Double? = nil,
        overrideElevationGain: Double? = nil,
        overrideElevationLoss: Double? = nil
    ) -> ActivityMetricsSummary {
        let start = overrideStartDate ?? points.first?.timestamp ?? Date()
        let end = overrideEndDate ?? points.last?.timestamp ?? start
        let elapsed = overrideElapsedTime ?? max(0, end.timeIntervalSince(start))

        var computedDist = 0.0
        var computedMoving: TimeInterval = 0
        var elevEngine = ElevationEngine(hysteresisMeters: elevationHysteresisMeters)

        if let first = points.first {
            elevEngine.ingest(altitudeMeters: first.altitude, verticalAccuracy: first.verticalAccuracy)
        }

        if points.count >= 2 {
            var movEngine = MovingTimeEngine(
                autoPauseEnabled: true,
                autoPauseSpeedThresholdMPS: activityType.defaultAutoPauseSpeedMPS
            )
            movEngine.start(at: points[0].timestamp)

            for idx in 1..<points.count {
                let p0 = points[idx - 1]
                let p1 = points[idx]
                elevEngine.ingest(altitudeMeters: p1.altitude, verticalAccuracy: p1.verticalAccuracy)

                if p0.isPaused && p1.isPaused {
                    movEngine.pauseManually(at: p1.timestamp)
                    continue
                } else if movEngine.isManuallyPaused {
                    movEngine.resumeManually(at: p1.timestamp)
                }

                let d = GeoMath.distanceMeters(from: p0, to: p1)
                let dt = max(0, p1.timestamp.timeIntervalSince(p0.timestamp))
                let segSpeed = dt > 0 ? (d / dt) : 0
                let effectiveSpeed = (p1.speed.isFinite && p1.speed > 0) ? p1.speed : segSpeed
                _ = movEngine.advance(to: p1.timestamp, speedMPS: effectiveSpeed)

                if !p1.isPaused && !movEngine.isAutoPaused {
                    computedDist += d
                }
            }
            computedMoving = movEngine.movingTime
        }

        let finalDist = overrideDistance ?? computedDist
        let finalMoving = overrideMovingTime ?? computedMoving
        let finalGain = overrideElevationGain ?? elevEngine.elevationGainMeters
        let finalLoss = overrideElevationLoss ?? elevEngine.elevationLossMeters

        let avgSpeed = finalMoving > 0 ? (finalDist / finalMoving) : 0
        let avgPace = (finalDist > 0 && finalMoving > 0) ? (finalMoving / finalDist) : 0

        let hrValues = points.compactMap(\.heartRate).filter { $0 > 20 && $0 < 240 }
        let avgHR = hrValues.isEmpty ? nil : (hrValues.reduce(0, +) / Double(hrValues.count))
        let maxHR = hrValues.max()

        let calories = estimateCalories(
            activityType: activityType,
            movingTimeSeconds: finalMoving,
            distanceMeters: finalDist,
            elevationGainMeters: finalGain,
            weightKg: userWeightKg
        )
        let effort = estimateEffortScore(
            activityType: activityType,
            movingTimeSeconds: finalMoving,
            averageSpeedMPS: avgSpeed,
            averageHeartRate: avgHR
        )

        let splits = SplitCalculator.computeSplits(
            points: points,
            unitSystem: unitSystem,
            movingThresholdMPS: activityType.defaultAutoPauseSpeedMPS * 0.5,
            elevationHysteresisMeters: elevationHysteresisMeters
        )
        let preview = downsamplePreview(points: points, maxCount: 60)

        return ActivityMetricsSummary(
            startDate: start,
            endDate: end,
            elapsedTime: elapsed,
            movingTime: finalMoving,
            distanceMeters: finalDist,
            elevationGainMeters: finalGain,
            elevationLossMeters: finalLoss,
            averagePaceSecondsPerMeter: avgPace,
            averageSpeedMPS: avgSpeed,
            averageHeartRate: avgHR,
            maxHeartRate: maxHR,
            estimatedCalories: calories,
            effortScore: effort,
            splits: splits,
            previewCoordinates: preview,
            pointCount: points.count
        )
    }

    public static func downsamplePreview(points: [TrackPoint], maxCount: Int = 60) -> [PreviewCoordinate] {
        guard !points.isEmpty else { return [] }
        let limit = max(2, maxCount)
        if points.count <= limit {
            return points.map { PreviewCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        }
        var result: [PreviewCoordinate] = []
        result.reserveCapacity(limit)
        let step = Double(points.count - 1) / Double(limit - 1)
        for i in 0..<limit {
            let idx = min(points.count - 1, Int((Double(i) * step).rounded()))
            let pt = points[idx]
            result.append(PreviewCoordinate(latitude: pt.latitude, longitude: pt.longitude))
        }
        return result
    }

    public static func estimateCalories(
        activityType: ActivityType,
        movingTimeSeconds: TimeInterval,
        distanceMeters: Double,
        elevationGainMeters: Double,
        weightKg: Double = 70.0
    ) -> Double {
        guard movingTimeSeconds > 0 else { return 0 }
        let hours = movingTimeSeconds / 3600.0
        let baseMET: Double
        switch activityType {
        case .run: baseMET = 9.8
        case .ride: baseMET = 7.5
        case .walk: baseMET = 3.8
        case .hike: baseMET = 6.0
        case .strength: baseMET = 5.0
        case .other: baseMET = 5.5
        }
        let climbBonusKcal = max(0, elevationGainMeters) * 0.12
        return max(0, baseMET * max(30.0, weightKg) * hours + climbBonusKcal)
    }

    public static func estimateEffortScore(
        activityType: ActivityType,
        movingTimeSeconds: TimeInterval,
        averageSpeedMPS: Double,
        averageHeartRate: Double?
    ) -> Double {
        guard movingTimeSeconds > 0 else { return 0 }
        let minutes = movingTimeSeconds / 60.0
        if let hr = averageHeartRate, hr > 40 {
            let hrRatio = min(1.0, max(0.1, (hr - 60.0) / 130.0))
            return minutes * hrRatio * exp(1.92 * hrRatio) * 0.45
        }
        if activityType == .strength {
            return minutes * 0.85
        }
        let referenceSpeed: Double
        switch activityType {
        case .run: referenceSpeed = 3.3
        case .ride: referenceSpeed = 7.5
        case .walk: referenceSpeed = 1.4
        case .hike: referenceSpeed = 1.2
        case .strength: referenceSpeed = 1.0
        case .other: referenceSpeed = 2.2
        }
        let intensity = min(2.0, max(0.35, averageSpeedMPS / referenceSpeed))
        return minutes * intensity * 1.15
    }
}
