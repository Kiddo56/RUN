import Foundation

public enum BackupError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case corruptedData
}

public struct BackupSettings: Codable, Sendable, Equatable {
    public var unitSystem: UnitSystem
    public var featureFlags: FeatureFlags
    public var autoPauseEnabled: Bool
    public var audioCuesEnabled: Bool
    public var hapticsEnabled: Bool
    public var maxHorizontalAccuracyMeters: Double
    public var elevationHysteresisMeters: Double
    public var userWeightKg: Double
    public var privacyHideRadiusMeters: Double

    public init(
        unitSystem: UnitSystem,
        featureFlags: FeatureFlags,
        autoPauseEnabled: Bool,
        audioCuesEnabled: Bool,
        hapticsEnabled: Bool,
        maxHorizontalAccuracyMeters: Double,
        elevationHysteresisMeters: Double,
        userWeightKg: Double,
        privacyHideRadiusMeters: Double
    ) {
        self.unitSystem = unitSystem
        self.featureFlags = featureFlags
        self.autoPauseEnabled = autoPauseEnabled
        self.audioCuesEnabled = audioCuesEnabled
        self.hapticsEnabled = hapticsEnabled
        self.maxHorizontalAccuracyMeters = maxHorizontalAccuracyMeters
        self.elevationHysteresisMeters = elevationHysteresisMeters
        self.userWeightKg = userWeightKg
        self.privacyHideRadiusMeters = privacyHideRadiusMeters
    }
}

public struct BackupActivityRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let activityType: ActivityType
    public let startDate: Date
    public let endDate: Date
    public let movingTime: TimeInterval
    public let elapsedTime: TimeInterval
    public let distanceMeters: Double
    public let elevationGainMeters: Double
    public let elevationLossMeters: Double
    public let averageHeartRate: Double?
    public let maxHeartRate: Double?
    public let effortScore: Double
    public let estimatedCalories: Double
    public let title: String
    public let notes: String
    public let gearID: UUID?
    public let source: String
    public let trackFileName: String
    public let trackBlobData: Data
    public let splits: [ActivitySplit]
    public let previewCoordinates: [PreviewCoordinate]
    public let pointCount: Int

    public init(
        id: UUID,
        activityType: ActivityType,
        startDate: Date,
        endDate: Date,
        movingTime: TimeInterval,
        elapsedTime: TimeInterval,
        distanceMeters: Double,
        elevationGainMeters: Double,
        elevationLossMeters: Double,
        averageHeartRate: Double?,
        maxHeartRate: Double?,
        effortScore: Double,
        estimatedCalories: Double,
        title: String,
        notes: String,
        gearID: UUID?,
        source: String,
        trackFileName: String,
        trackBlobData: Data,
        splits: [ActivitySplit],
        previewCoordinates: [PreviewCoordinate],
        pointCount: Int
    ) {
        self.id = id
        self.activityType = activityType
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
        self.trackBlobData = trackBlobData
        self.splits = splits
        self.previewCoordinates = previewCoordinates
        self.pointCount = pointCount
    }
}

public struct BackupGearRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let categoryRaw: String
    public let brand: String
    public let initialDistanceMeters: Double
    public let maxDistanceMeters: Double
    public let isRetired: Bool
    public let isDefaultForRun: Bool
    public let isDefaultForRide: Bool
    public let notes: String
    public let addedDate: Date

    public init(
        id: UUID,
        name: String,
        categoryRaw: String,
        brand: String,
        initialDistanceMeters: Double,
        maxDistanceMeters: Double,
        isRetired: Bool,
        isDefaultForRun: Bool,
        isDefaultForRide: Bool,
        notes: String,
        addedDate: Date
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

public struct BackupGoalRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let periodRaw: String
    public let metricRaw: String
    public let targetValue: Double
    public let activityTypeRaw: String?
    public let reminderEnabled: Bool
    public let reminderWeekday: Int
    public let reminderHour: Int
    public let createdAt: Date

    public init(
        id: UUID,
        title: String,
        periodRaw: String,
        metricRaw: String,
        targetValue: Double,
        activityTypeRaw: String?,
        reminderEnabled: Bool,
        reminderWeekday: Int,
        reminderHour: Int,
        createdAt: Date
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

public struct BackupRouteRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let notes: String
    public let createdAt: Date
    public let distanceMeters: Double
    public let elevationGainMeters: Double
    public let source: String
    public let waypoints: [RouteWaypoint]

    public init(
        id: UUID,
        name: String,
        notes: String,
        createdAt: Date,
        distanceMeters: Double,
        elevationGainMeters: Double,
        source: String,
        waypoints: [RouteWaypoint]
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.source = source
        self.waypoints = waypoints
    }
}

public struct BackupSectionRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let activityTypeRaw: String
    public let startLatitude: Double
    public let startLongitude: Double
    public let endLatitude: Double
    public let endLongitude: Double
    public let expectedBearing: Double
    public let distanceMeters: Double
    public let corridorMeters: Double
    public let createdAt: Date

    public init(
        id: UUID,
        name: String,
        activityTypeRaw: String,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double,
        expectedBearing: Double,
        distanceMeters: Double,
        corridorMeters: Double,
        createdAt: Date
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

public struct BackupEnvelope: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let exportedAt: Date
    public let appVersion: String
    public let settings: BackupSettings
    public let activities: [BackupActivityRecord]
    public let gear: [BackupGearRecord]
    public let goals: [BackupGoalRecord]
    public let routes: [BackupRouteRecord]
    public let sections: [BackupSectionRecord]

    public init(
        schemaVersion: Int = BackupEnvelope.currentSchemaVersion,
        exportedAt: Date = Date(),
        appVersion: String,
        settings: BackupSettings,
        activities: [BackupActivityRecord],
        gear: [BackupGearRecord],
        goals: [BackupGoalRecord],
        routes: [BackupRouteRecord],
        sections: [BackupSectionRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.settings = settings
        self.activities = activities
        self.gear = gear
        self.goals = goals
        self.routes = routes
        self.sections = sections
    }
}

public enum BackupCodec {
    public static func encode(_ envelope: BackupEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }

    public static func decode(_ data: Data) throws -> BackupEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(BackupEnvelope.self, from: data)
        guard envelope.schemaVersion >= 1 && envelope.schemaVersion <= BackupEnvelope.currentSchemaVersion else {
            throw BackupError.unsupportedSchemaVersion(envelope.schemaVersion)
        }
        return envelope
    }
}
