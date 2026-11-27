import Foundation

public enum MuscleGroup: String, CaseIterable, Codable, Sendable, Identifiable {
    case legs
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case forearms
    case core
    case fullBody
    case mobility

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .legs: return "Legs"
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .core: return "Core"
        case .fullBody: return "Full Body & Conditioning"
        case .mobility: return "Mobility & Stretching"
        }
    }

    public var shortName: String {
        switch self {
        case .legs: return "Legs"
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .core: return "Core"
        case .fullBody: return "Full Body"
        case .mobility: return "Mobility"
        }
    }

    public var symbolName: String {
        switch self {
        case .legs: return "figure.walk.motion"
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rowing"
        case .shoulders: return "figure.arms.open"
        case .biceps: return "dumbbell.fill"
        case .triceps: return "dumbbell"
        case .forearms: return "hand.raised.fill"
        case .core: return "figure.core.training"
        case .fullBody: return "flame.fill"
        case .mobility: return "figure.flexibility"
        }
    }
}

public enum ExerciseEquipment: String, CaseIterable, Codable, Sendable, Identifiable {
    case bodyweight
    case barbell
    case dumbbell
    case machine
    case cable
    case kettlebell
    case resistanceBand
    case pullUpBar
    case bench

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bodyweight: return "Bodyweight"
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .machine: return "Machine"
        case .cable: return "Cable"
        case .kettlebell: return "Kettlebell"
        case .resistanceBand: return "Resistance Band"
        case .pullUpBar: return "Pull-Up Bar"
        case .bench: return "Bench"
        }
    }
}

public enum ExerciseMechanic: String, CaseIterable, Codable, Sendable, Identifiable {
    case compound
    case isolation

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }
}

public enum ExerciseDifficulty: String, CaseIterable, Codable, Sendable, Identifiable {
    case beginner
    case intermediate
    case advanced

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }
}

public enum ExerciseTrackingType: String, CaseIterable, Codable, Sendable, Identifiable {
    case weightReps
    case repsOnly
    case timeOnly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .weightReps: return "Weight & Reps"
        case .repsOnly: return "Reps Only"
        case .timeOnly: return "Time Only"
        }
    }
}

public enum SetType: String, CaseIterable, Codable, Sendable, Identifiable {
    case warmUp
    case normal
    case drop
    case failure

    public var id: String { rawValue }

    public var shortTag: String {
        switch self {
        case .warmUp: return "W"
        case .normal: return "N"
        case .drop: return "D"
        case .failure: return "F"
        }
    }

    public var displayName: String {
        switch self {
        case .warmUp: return "Warm-Up"
        case .normal: return "Normal"
        case .drop: return "Drop Set"
        case .failure: return "To Failure"
        }
    }

    public var countsTowardPRAndVolume: Bool {
        self != .warmUp
    }
}

public struct CatalogExercise: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let aliases: [String]
    public let muscleGroup: MuscleGroup
    public let primaryMuscles: [String]
    public let secondaryMuscles: [String]
    public let equipment: [ExerciseEquipment]
    public let mechanic: ExerciseMechanic
    public let difficulty: ExerciseDifficulty
    public let trackingType: ExerciseTrackingType
    public let instructions: [String]
    public let tips: String
    public let commonMistakes: String
    public let isCustom: Bool

    public init(
        id: String,
        name: String,
        aliases: [String] = [],
        muscleGroup: MuscleGroup,
        primaryMuscles: [String],
        secondaryMuscles: [String] = [],
        equipment: [ExerciseEquipment],
        mechanic: ExerciseMechanic,
        difficulty: ExerciseDifficulty,
        trackingType: ExerciseTrackingType,
        instructions: [String],
        tips: String,
        commonMistakes: String,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.muscleGroup = muscleGroup
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.mechanic = mechanic
        self.difficulty = difficulty
        self.trackingType = trackingType
        self.instructions = instructions
        self.tips = tips
        self.commonMistakes = commonMistakes
        self.isCustom = isCustom
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, aliases, muscleGroup, primaryMuscles, secondaryMuscles
        case equipment, mechanic, difficulty, trackingType, instructions, tips, commonMistakes, isCustom
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        self.muscleGroup = try c.decode(MuscleGroup.self, forKey: .muscleGroup)
        self.primaryMuscles = try c.decode([String].self, forKey: .primaryMuscles)
        self.secondaryMuscles = try c.decodeIfPresent([String].self, forKey: .secondaryMuscles) ?? []
        self.equipment = try c.decode([ExerciseEquipment].self, forKey: .equipment)
        self.mechanic = try c.decode(ExerciseMechanic.self, forKey: .mechanic)
        self.difficulty = try c.decode(ExerciseDifficulty.self, forKey: .difficulty)
        self.trackingType = try c.decode(ExerciseTrackingType.self, forKey: .trackingType)
        self.instructions = try c.decode([String].self, forKey: .instructions)
        self.tips = try c.decode(String.self, forKey: .tips)
        self.commonMistakes = try c.decode(String.self, forKey: .commonMistakes)
        self.isCustom = try c.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }
}

public struct ExerciseCatalogDocument: Codable, Sendable, Equatable {
    public let catalogVersion: Int
    public let exercises: [CatalogExercise]

    public init(catalogVersion: Int, exercises: [CatalogExercise]) {
        self.catalogVersion = catalogVersion
        self.exercises = exercises
    }
}
