import Foundation

public struct ActivitySplit: Codable, Sendable, Equatable, Identifiable {
    public let index: Int
    public let distanceMeters: Double
    public let durationSeconds: TimeInterval
    public let movingSeconds: TimeInterval
    public let elevationGainMeters: Double
    public let elevationLossMeters: Double
    public let averageHeartRate: Double?
    public let isPartial: Bool

    public var id: Int { index }

    public var paceSecondsPerMeter: Double {
        guard distanceMeters > 0, movingSeconds > 0 else { return 0 }
        return movingSeconds / distanceMeters
    }

    public var speedMPS: Double {
        guard movingSeconds > 0 else { return 0 }
        return distanceMeters / movingSeconds
    }

    public init(
        index: Int,
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        movingSeconds: TimeInterval,
        elevationGainMeters: Double,
        elevationLossMeters: Double,
        averageHeartRate: Double? = nil,
        isPartial: Bool = false
    ) {
        self.index = index
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.movingSeconds = movingSeconds
        self.elevationGainMeters = elevationGainMeters
        self.elevationLossMeters = elevationLossMeters
        self.averageHeartRate = averageHeartRate
        self.isPartial = isPartial
    }
}

public struct PreviewCoordinate: Codable, Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct ActivityMetricsSummary: Codable, Sendable, Equatable {
    public let startDate: Date
    public let endDate: Date
    public let elapsedTime: TimeInterval
    public let movingTime: TimeInterval
    public let distanceMeters: Double
    public let elevationGainMeters: Double
    public let elevationLossMeters: Double
    public let averagePaceSecondsPerMeter: Double
    public let averageSpeedMPS: Double
    public let averageHeartRate: Double?
    public let maxHeartRate: Double?
    public let estimatedCalories: Double
    public let effortScore: Double
    public let splits: [ActivitySplit]
    public let previewCoordinates: [PreviewCoordinate]
    public let pointCount: Int

    public init(
        startDate: Date,
        endDate: Date,
        elapsedTime: TimeInterval,
        movingTime: TimeInterval,
        distanceMeters: Double,
        elevationGainMeters: Double,
        elevationLossMeters: Double,
        averagePaceSecondsPerMeter: Double,
        averageSpeedMPS: Double,
        averageHeartRate: Double?,
        maxHeartRate: Double?,
        estimatedCalories: Double,
        effortScore: Double,
        splits: [ActivitySplit],
        previewCoordinates: [PreviewCoordinate],
        pointCount: Int
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.elapsedTime = elapsedTime
        self.movingTime = movingTime
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.elevationLossMeters = elevationLossMeters
        self.averagePaceSecondsPerMeter = averagePaceSecondsPerMeter
        self.averageSpeedMPS = averageSpeedMPS
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.estimatedCalories = estimatedCalories
        self.effortScore = effortScore
        self.splits = splits
        self.previewCoordinates = previewCoordinates
        self.pointCount = pointCount
    }
}
