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

    // v2 additive optional settings (nil when decoding v1 backups)
    public var weightUnit: WeightUnit?
    public var keepScreenAwakeWhileRecording: Bool?
    public var keepScreenAwakeDuringWorkout: Bool?
    public var selectedVoiceIdentifier: String?
    public var speechRate: Float?
    public var speechPitch: Float?
    public var speechVolume: Float?
    public var cueEveryUnitEnabled: Bool?
    public var cueEveryNMinutes: Int?
    public var cueOnLapEnabled: Bool?
    public var cueOnPauseResumeEnabled: Bool?
    public var cueOnGoalReachedEnabled: Bool?
    public var defaultRestSeconds: Int?

    public init(
        unitSystem: UnitSystem,
        featureFlags: FeatureFlags,
        autoPauseEnabled: Bool,
        audioCuesEnabled: Bool,
        hapticsEnabled: Bool,
        maxHorizontalAccuracyMeters: Double,
        elevationHysteresisMeters: Double,
        userWeightKg: Double,
        privacyHideRadiusMeters: Double,
        weightUnit: WeightUnit? = nil,
        keepScreenAwakeWhileRecording: Bool? = nil,
        keepScreenAwakeDuringWorkout: Bool? = nil,
        selectedVoiceIdentifier: String? = nil,
        speechRate: Float? = nil,
        speechPitch: Float? = nil,
        speechVolume: Float? = nil,
        cueEveryUnitEnabled: Bool? = nil,
        cueEveryNMinutes: Int? = nil,
        cueOnLapEnabled: Bool? = nil,
        cueOnPauseResumeEnabled: Bool? = nil,
        cueOnGoalReachedEnabled: Bool? = nil,
        defaultRestSeconds: Int? = nil
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
        self.weightUnit = weightUnit
        self.keepScreenAwakeWhileRecording = keepScreenAwakeWhileRecording
        self.keepScreenAwakeDuringWorkout = keepScreenAwakeDuringWorkout
        self.selectedVoiceIdentifier = selectedVoiceIdentifier
        self.speechRate = speechRate
        self.speechPitch = speechPitch
        self.speechVolume = speechVolume
        self.cueEveryUnitEnabled = cueEveryUnitEnabled
        self.cueEveryNMinutes = cueEveryNMinutes
        self.cueOnLapEnabled = cueOnLapEnabled
        self.cueOnPauseResumeEnabled = cueOnPauseResumeEnabled
        self.cueOnGoalReachedEnabled = cueOnGoalReachedEnabled
        self.defaultRestSeconds = defaultRestSeconds
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

// MARK: - v2 Additive Fitness Backup Records

public struct BackupCustomExerciseRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let slug: String
    public let name: String
    public let muscleGroupRaw: String
    public let primaryMusclesCSV: String
    public let secondaryMusclesCSV: String
    public let equipmentCSV: String
    public let mechanicRaw: String
    public let difficultyRaw: String
    public let trackingTypeRaw: String
    public let instructionsText: String
    public let tips: String
    public let commonMistakes: String
    public let createdAt: Date

    public init(
        id: UUID,
        slug: String,
        name: String,
        muscleGroupRaw: String,
        primaryMusclesCSV: String,
        secondaryMusclesCSV: String,
        equipmentCSV: String,
        mechanicRaw: String,
        difficultyRaw: String,
        trackingTypeRaw: String,
        instructionsText: String,
        tips: String,
        commonMistakes: String,
        createdAt: Date
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

public struct BackupExercisePreferenceRecord: Codable, Sendable, Equatable {
    public let exerciseSlug: String
    public let isFavorite: Bool
    public let personalNotes: String
    public let defaultRestSeconds: Int
    public let updatedAt: Date

    public init(
        exerciseSlug: String,
        isFavorite: Bool,
        personalNotes: String,
        defaultRestSeconds: Int,
        updatedAt: Date
    ) {
        self.exerciseSlug = exerciseSlug
        self.isFavorite = isFavorite
        self.personalNotes = personalNotes
        self.defaultRestSeconds = defaultRestSeconds
        self.updatedAt = updatedAt
    }
}

public struct BackupWorkoutSessionRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let notes: String
    public let startDate: Date
    public let endDate: Date?
    public let durationSeconds: TimeInterval
    public let isCompleted: Bool
    public let templateID: UUID?
    public let linkedActivityID: UUID?
    public let totalVolumeKg: Double
    public let completedSetCount: Int
    public let exerciseCount: Int

    public init(
        id: UUID,
        title: String,
        notes: String,
        startDate: Date,
        endDate: Date?,
        durationSeconds: TimeInterval,
        isCompleted: Bool,
        templateID: UUID?,
        linkedActivityID: UUID?,
        totalVolumeKg: Double,
        completedSetCount: Int,
        exerciseCount: Int
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

public struct BackupWorkoutExerciseEntryRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let workoutSessionID: UUID
    public let exerciseSlug: String
    public let exerciseNameSnapshot: String
    public let muscleGroupRaw: String
    public let trackingTypeRaw: String
    public let orderIndex: Int
    public let restSeconds: Int
    public let notes: String

    public init(
        id: UUID,
        workoutSessionID: UUID,
        exerciseSlug: String,
        exerciseNameSnapshot: String,
        muscleGroupRaw: String,
        trackingTypeRaw: String,
        orderIndex: Int,
        restSeconds: Int,
        notes: String
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

public struct BackupSetEntryRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let workoutSessionID: UUID
    public let workoutExerciseEntryID: UUID
    public let exerciseSlug: String
    public let orderIndex: Int
    public let setTypeRaw: String
    public let weightKg: Double
    public let reps: Int
    public let durationSeconds: Int
    public let rpe: Double?
    public let isCompleted: Bool
    public let completedAt: Date?
    public let isPRWeight: Bool
    public let isPREstimated1RM: Bool
    public let isPRReps: Bool
    public let isPRVolume: Bool

    public init(
        id: UUID,
        workoutSessionID: UUID,
        workoutExerciseEntryID: UUID,
        exerciseSlug: String,
        orderIndex: Int,
        setTypeRaw: String,
        weightKg: Double,
        reps: Int,
        durationSeconds: Int,
        rpe: Double?,
        isCompleted: Bool,
        completedAt: Date?,
        isPRWeight: Bool,
        isPREstimated1RM: Bool,
        isPRReps: Bool,
        isPRVolume: Bool
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

public struct BackupWorkoutTemplateRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let notes: String
    public let isBuiltIn: Bool
    public let builtInKey: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        name: String,
        notes: String,
        isBuiltIn: Bool,
        builtInKey: String?,
        createdAt: Date,
        updatedAt: Date
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

public struct BackupWorkoutTemplateItemRecord: Codable, Sendable, Equatable {
    public let id: UUID
    public let templateID: UUID
    public let exerciseSlug: String
    public let exerciseNameSnapshot: String
    public let orderIndex: Int
    public let targetSets: Int
    public let targetRepsMin: Int
    public let targetRepsMax: Int
    public let targetDurationSeconds: Int
    public let defaultRestSeconds: Int
    public let notes: String

    public init(
        id: UUID,
        templateID: UUID,
        exerciseSlug: String,
        exerciseNameSnapshot: String,
        orderIndex: Int,
        targetSets: Int,
        targetRepsMin: Int,
        targetRepsMax: Int,
        targetDurationSeconds: Int,
        defaultRestSeconds: Int,
        notes: String
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

public struct BackupEnvelope: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let exportedAt: Date
    public let appVersion: String
    public let settings: BackupSettings
    public let activities: [BackupActivityRecord]
    public let gear: [BackupGearRecord]
    public let goals: [BackupGoalRecord]
    public let routes: [BackupRouteRecord]
    public let sections: [BackupSectionRecord]

    // v2 additive arrays (default to [] when restoring v1 backups)
    public let customExercises: [BackupCustomExerciseRecord]
    public let exercisePreferences: [BackupExercisePreferenceRecord]
    public let workoutSessions: [BackupWorkoutSessionRecord]
    public let workoutExerciseEntries: [BackupWorkoutExerciseEntryRecord]
    public let setEntries: [BackupSetEntryRecord]
    public let workoutTemplates: [BackupWorkoutTemplateRecord]
    public let workoutTemplateItems: [BackupWorkoutTemplateItemRecord]

    public init(
        schemaVersion: Int = BackupEnvelope.currentSchemaVersion,
        exportedAt: Date = Date(),
        appVersion: String,
        settings: BackupSettings,
        activities: [BackupActivityRecord],
        gear: [BackupGearRecord],
        goals: [BackupGoalRecord],
        routes: [BackupRouteRecord],
        sections: [BackupSectionRecord],
        customExercises: [BackupCustomExerciseRecord] = [],
        exercisePreferences: [BackupExercisePreferenceRecord] = [],
        workoutSessions: [BackupWorkoutSessionRecord] = [],
        workoutExerciseEntries: [BackupWorkoutExerciseEntryRecord] = [],
        setEntries: [BackupSetEntryRecord] = [],
        workoutTemplates: [BackupWorkoutTemplateRecord] = [],
        workoutTemplateItems: [BackupWorkoutTemplateItemRecord] = []
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
        self.customExercises = customExercises
        self.exercisePreferences = exercisePreferences
        self.workoutSessions = workoutSessions
        self.workoutExerciseEntries = workoutExerciseEntries
        self.setEntries = setEntries
        self.workoutTemplates = workoutTemplates
        self.workoutTemplateItems = workoutTemplateItems
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case exportedAt
        case appVersion
        case settings
        case activities
        case gear
        case goals
        case routes
        case sections
        case customExercises
        case exercisePreferences
        case workoutSessions
        case workoutExerciseEntries
        case setEntries
        case workoutTemplates
        case workoutTemplateItems
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        self.appVersion = try c.decode(String.self, forKey: .appVersion)
        self.settings = try c.decode(BackupSettings.self, forKey: .settings)
        self.activities = try c.decodeIfPresent([BackupActivityRecord].self, forKey: .activities) ?? []
        self.gear = try c.decodeIfPresent([BackupGearRecord].self, forKey: .gear) ?? []
        self.goals = try c.decodeIfPresent([BackupGoalRecord].self, forKey: .goals) ?? []
        self.routes = try c.decodeIfPresent([BackupRouteRecord].self, forKey: .routes) ?? []
        self.sections = try c.decodeIfPresent([BackupSectionRecord].self, forKey: .sections) ?? []
        self.customExercises = try c.decodeIfPresent([BackupCustomExerciseRecord].self, forKey: .customExercises) ?? []
        self.exercisePreferences = try c.decodeIfPresent([BackupExercisePreferenceRecord].self, forKey: .exercisePreferences) ?? []
        self.workoutSessions = try c.decodeIfPresent([BackupWorkoutSessionRecord].self, forKey: .workoutSessions) ?? []
        self.workoutExerciseEntries = try c.decodeIfPresent([BackupWorkoutExerciseEntryRecord].self, forKey: .workoutExerciseEntries) ?? []
        self.setEntries = try c.decodeIfPresent([BackupSetEntryRecord].self, forKey: .setEntries) ?? []
        self.workoutTemplates = try c.decodeIfPresent([BackupWorkoutTemplateRecord].self, forKey: .workoutTemplates) ?? []
        self.workoutTemplateItems = try c.decodeIfPresent([BackupWorkoutTemplateItemRecord].self, forKey: .workoutTemplateItems) ?? []
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
