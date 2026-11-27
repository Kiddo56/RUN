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

    func decodedWaypoints() -> [RouteWaypoint] {
        guard !waypointsData.isEmpty,
              let decoded = try? JSONDecoder().decode([RouteWaypoint].self, from: waypointsData) else {
            return []
        }
        return decoded
    }

    func updateWaypoints(_ waypoints: [RouteWaypoint]) {
        self.waypointsData = (try? JSONEncoder().encode(waypoints)) ?? Data()
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

// MARK: - v2 Additive Strength & Fitness Models

@Model
final class SDCustomExercise {
    @Attribute(.unique) var id: UUID
    var slug: String
    var name: String
    var muscleGroupRaw: String
    var primaryMusclesCSV: String
    var secondaryMusclesCSV: String
    var equipmentCSV: String
    var mechanicRaw: String
    var difficultyRaw: String
    var trackingTypeRaw: String
    var instructionsText: String
    var tips: String
    var commonMistakes: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        slug: String,
        name: String,
        muscleGroupRaw: String,
        primaryMusclesCSV: String = "",
        secondaryMusclesCSV: String = "",
        equipmentCSV: String = "bodyweight",
        mechanicRaw: String = "compound",
        difficultyRaw: String = "intermediate",
        trackingTypeRaw: String = "weightReps",
        instructionsText: String = "",
        tips: String = "",
        commonMistakes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.muscleGroupRaw = muscleGroupRaw
        self.primaryMusclesCSV = primaryMusclesCSV
        self.secondaryMusclesCSV = secondaryMusclesCSV
        self.equipmentCSV = equipmentCSV
        self.mechanicRaw = mechanicRaw
        self.difficultyRaw = difficultyRaw
        self.trackingTypeRaw = trackingTypeRaw
        self.instructionsText = instructionsText
        self.tips = tips
        self.commonMistakes = commonMistakes
        self.createdAt = createdAt
    }
}

@Model
final class SDExercisePreference {
    @Attribute(.unique) var exerciseSlug: String
    var isFavorite: Bool
    var personalNotes: String
    var defaultRestSeconds: Int
    var updatedAt: Date

    init(
        exerciseSlug: String,
        isFavorite: Bool = false,
        personalNotes: String = "",
        defaultRestSeconds: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.exerciseSlug = exerciseSlug
        self.isFavorite = isFavorite
        self.personalNotes = personalNotes
        self.defaultRestSeconds = defaultRestSeconds
        self.updatedAt = updatedAt
    }
}

@Model
final class SDWorkoutSession {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var startDate: Date
    var endDate: Date?
    var durationSeconds: TimeInterval
    var isCompleted: Bool
    var templateID: UUID?
    var linkedActivityID: UUID?
    var totalVolumeKg: Double
    var completedSetCount: Int
    var exerciseCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        startDate: Date = Date(),
        endDate: Date? = nil,
        durationSeconds: TimeInterval = 0,
        isCompleted: Bool = false,
        templateID: UUID? = nil,
        linkedActivityID: UUID? = nil,
        totalVolumeKg: Double = 0,
        completedSetCount: Int = 0,
        exerciseCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.durationSeconds = durationSeconds
        self.isCompleted = isCompleted
        self.templateID = templateID
        self.linkedActivityID = linkedActivityID
        self.totalVolumeKg = totalVolumeKg
        self.completedSetCount = completedSetCount
        self.exerciseCount = exerciseCount
    }
}

@Model
final class SDWorkoutExerciseEntry {
    @Attribute(.unique) var id: UUID
    var workoutSessionID: UUID
    var exerciseSlug: String
    var exerciseNameSnapshot: String
    var muscleGroupRaw: String
    var trackingTypeRaw: String
    var orderIndex: Int
    var restSeconds: Int
    var notes: String

    init(
        id: UUID = UUID(),
        workoutSessionID: UUID,
        exerciseSlug: String,
        exerciseNameSnapshot: String,
        muscleGroupRaw: String,
        trackingTypeRaw: String = "weightReps",
        orderIndex: Int,
        restSeconds: Int = 90,
        notes: String = ""
    ) {
        self.id = id
        self.workoutSessionID = workoutSessionID
        self.exerciseSlug = exerciseSlug
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.muscleGroupRaw = muscleGroupRaw
        self.trackingTypeRaw = trackingTypeRaw
        self.orderIndex = orderIndex
        self.restSeconds = restSeconds
        self.notes = notes
    }
}

@Model
final class SDSetEntry {
    @Attribute(.unique) var id: UUID
    var workoutSessionID: UUID
    var workoutExerciseEntryID: UUID
    var exerciseSlug: String
    var orderIndex: Int
    var setTypeRaw: String
    var weightKg: Double
    var reps: Int
    var durationSeconds: Int
    var rpe: Double?
    var isCompleted: Bool
    var completedAt: Date?
    var isPRWeight: Bool
    var isPREstimated1RM: Bool
    var isPRReps: Bool
    var isPRVolume: Bool

    init(
        id: UUID = UUID(),
        workoutSessionID: UUID,
        workoutExerciseEntryID: UUID,
        exerciseSlug: String,
        orderIndex: Int,
        setTypeRaw: String = "normal",
        weightKg: Double = 0,
        reps: Int = 0,
        durationSeconds: Int = 0,
        rpe: Double? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isPRWeight: Bool = false,
        isPREstimated1RM: Bool = false,
        isPRReps: Bool = false,
        isPRVolume: Bool = false
    ) {
        self.id = id
        self.workoutSessionID = workoutSessionID
        self.workoutExerciseEntryID = workoutExerciseEntryID
        self.exerciseSlug = exerciseSlug
        self.orderIndex = orderIndex
        self.setTypeRaw = setTypeRaw
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.rpe = rpe
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.isPRWeight = isPRWeight
        self.isPREstimated1RM = isPREstimated1RM
        self.isPRReps = isPRReps
        self.isPRVolume = isPRVolume
    }
}

@Model
final class SDWorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    var isBuiltIn: Bool
    var builtInKey: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        isBuiltIn: Bool = false,
        builtInKey: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.isBuiltIn = isBuiltIn
        self.builtInKey = builtInKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class SDWorkoutTemplateItem {
    @Attribute(.unique) var id: UUID
    var templateID: UUID
    var exerciseSlug: String
    var exerciseNameSnapshot: String
    var orderIndex: Int
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetDurationSeconds: Int
    var defaultRestSeconds: Int
    var notes: String

    init(
        id: UUID = UUID(),
        templateID: UUID,
        exerciseSlug: String,
        exerciseNameSnapshot: String,
        orderIndex: Int,
        targetSets: Int = 3,
        targetRepsMin: Int = 8,
        targetRepsMax: Int = 12,
        targetDurationSeconds: Int = 0,
        defaultRestSeconds: Int = 90,
        notes: String = ""
    ) {
        self.id = id
        self.templateID = templateID
        self.exerciseSlug = exerciseSlug
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.targetDurationSeconds = targetDurationSeconds
        self.defaultRestSeconds = defaultRestSeconds
        self.notes = notes
    }
}

// MARK: - Versioned Schemas & Lightweight Migration Plan (v1 -> v2)

enum RunSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [
            SDActivity.self,
            SDGear.self,
            SDGoal.self,
            SDSavedRoute.self,
            SDSection.self
        ]
    }
}

enum RunSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [
            SDActivity.self,
            SDGear.self,
            SDGoal.self,
            SDSavedRoute.self,
            SDSection.self,
            SDCustomExercise.self,
            SDExercisePreference.self,
            SDWorkoutSession.self,
            SDWorkoutExerciseEntry.self,
            SDSetEntry.self,
            SDWorkoutTemplate.self,
            SDWorkoutTemplateItem.self
        ]
    }
}

enum RunMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [RunSchemaV1.self, RunSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            MigrationStage.lightweight(
                fromVersion: RunSchemaV1.self,
                toVersion: RunSchemaV2.self
            )
        ]
    }
}

enum RunModelContainerFactory {
    static func makeContainer(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: RunSchemaV2.self)
        let config: ModelConfiguration
        if let url {
            config = ModelConfiguration(schema: schema, url: url)
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: RunMigrationPlan.self,
            configurations: [config]
        )
    }
}
