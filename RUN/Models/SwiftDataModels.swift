import Foundation
import SwiftData
import TrackerCore

@Model
final class SDActivity {
    @Attribute(.unique) var id: UUID
    var activityTypeRaw: String
    var startDate: Date
    var endDate: Date
    var movingTime: TimeInterval
    var elapsedTime: TimeInterval
    var distanceMeters: Double
    var elevationGainMeters: Double
    var elevationLossMeters: Double
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var effortScore: Double
    var estimatedCalories: Double
    var title: String
    var notes: String
    var gearID: UUID?
    var source: String
    var trackFileName: String
    var splitsData: Data?
    var previewCoordinatesData: Data?
    var pointCount: Int

    init(
        id: UUID = UUID(),
        activityType: ActivityType,
        startDate: Date,
        endDate: Date,
        movingTime: TimeInterval,
        elapsedTime: TimeInterval,
        distanceMeters: Double,
        elevationGainMeters: Double,
        elevationLossMeters: Double = 0,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        effortScore: Double = 0,
        estimatedCalories: Double = 0,
        title: String,
        notes: String = "",
        gearID: UUID? = nil,
        source: String = "recorded",
        trackFileName: String,
        splits: [ActivitySplit] = [],
        previewCoordinates: [PreviewCoordinate] = [],
        pointCount: Int = 0
    ) {
        self.id = id
        self.activityTypeRaw = activityType.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.movingTime = movingTime
        self.elapsedTime = elapsedTime
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.elevationLossMeters = elevationLossMeters
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.effortScore = effortScore
        self.estimatedCalories = estimatedCalories
        self.title = title
        self.notes = notes
        self.gearID = gearID
        self.source = source
        self.trackFileName = trackFileName
        self.splitsData = try? JSONEncoder().encode(splits)
        self.previewCoordinatesData = try? JSONEncoder().encode(previewCoordinates)
        self.pointCount = pointCount
    }

    var activityType: ActivityType {
        get { ActivityType(rawValue: activityTypeRaw) ?? .other }
        set { activityTypeRaw = newValue.rawValue }
    }

    var averagePaceSecondsPerMeter: Double {
        guard distanceMeters > 0, movingTime > 0 else { return 0 }
        return movingTime / distanceMeters
    }

    var averageSpeedMPS: Double {
        guard movingTime > 0 else { return 0 }
        return distanceMeters / movingTime
    }

    func decodedSplits() -> [ActivitySplit] {
        guard let splitsData,
              let decoded = try? JSONDecoder().decode([ActivitySplit].self, from: splitsData) else {
            return []
        }
        return decoded
    }

    func updateSplits(_ splits: [ActivitySplit]) {
        self.splitsData = try? JSONEncoder().encode(splits)
    }

    func decodedPreviewCoordinates() -> [PreviewCoordinate] {
        guard let previewCoordinatesData,
              let decoded = try? JSONDecoder().decode([PreviewCoordinate].self, from: previewCoordinatesData) else {
            return []
        }
        return decoded
    }

    func updatePreviewCoordinates(_ coordinates: [PreviewCoordinate]) {
        self.previewCoordinatesData = try? JSONEncoder().encode(coordinates)
    }
}

@Model
final class SDGear {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String
    var brand: String
    var initialDistanceMeters: Double
    var maxDistanceMeters: Double
    var isRetired: Bool
    var isDefaultForRun: Bool
    var isDefaultForRide: Bool
    var notes: String
    var addedDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        categoryRaw: String = "shoes",
        brand: String = "",
        initialDistanceMeters: Double = 0,
        maxDistanceMeters: Double = 800_000,
        isRetired: Bool = false,
        isDefaultForRun: Bool = false,
        isDefaultForRide: Bool = false,
        notes: String = "",
        addedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = categoryRaw
        self.brand = brand
        self.initialDistanceMeters = initialDistanceMeters
        self.maxDistanceMeters = maxDistanceMeters
        self.isRetired = isRetired
        self.isDefaultForRun = isDefaultForRun
        self.isDefaultForRide = isDefaultForRide
        self.notes = notes
        self.addedDate = addedDate
    }
}

@Model
final class SDGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var periodRaw: String
    var metricRaw: String
    var targetValue: Double
    var activityTypeRaw: String?
    var reminderEnabled: Bool
    var reminderWeekday: Int
    var reminderHour: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        periodRaw: String = "weekly",
        metricRaw: String = "distanceMeters",
        targetValue: Double,
        activityTypeRaw: String? = nil,
        reminderEnabled: Bool = false,
        reminderWeekday: Int = 1,
        reminderHour: Int = 9,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.periodRaw = periodRaw
        self.metricRaw = metricRaw
        self.targetValue = targetValue
        self.activityTypeRaw = activityTypeRaw
        self.reminderEnabled = reminderEnabled
        self.reminderWeekday = reminderWeekday
        self.reminderHour = reminderHour
        self.createdAt = createdAt
    }
}

@Model
final class SDSavedRoute {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    var createdAt: Date
    var distanceMeters: Double
    var elevationGainMeters: Double
    var source: String
    var waypointsData: Data

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        createdAt: Date = Date(),
        distanceMeters: Double = 0,
        elevationGainMeters: Double = 0,
        source: String = "drawn",
        waypointsData: Data = Data()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.source = source
        self.waypointsData = waypointsData
    }
}

@Model
final class SDSection {
    @Attribute(.unique) var id: UUID
    var name: String
    var activityTypeRaw: String
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double
    var endLongitude: Double
    var expectedBearing: Double
    var distanceMeters: Double
    var corridorMeters: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        activityTypeRaw: String = ActivityType.run.rawValue,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double,
        expectedBearing: Double,
        distanceMeters: Double,
        corridorMeters: Double = 35.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.activityTypeRaw = activityTypeRaw
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.expectedBearing = expectedBearing
        self.distanceMeters = distanceMeters
        self.corridorMeters = corridorMeters
        self.createdAt = createdAt
    }
}
