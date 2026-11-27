import Foundation

public struct StrengthSetSnapshot: Sendable, Equatable {
    public let id: UUID
    public let workoutSessionID: UUID
    public let workoutDate: Date
    public let exerciseSlug: String
    public let setType: SetType
    public let weightKg: Double
    public let reps: Int
    public let durationSeconds: Int
    public let rpe: Double?
    public let isCompleted: Bool

    public init(
        id: UUID,
        workoutSessionID: UUID,
        workoutDate: Date,
        exerciseSlug: String,
        setType: SetType,
        weightKg: Double,
        reps: Int,
        durationSeconds: Int = 0,
        rpe: Double? = nil,
        isCompleted: Bool = true
    ) {
        self.id = id
        self.workoutSessionID = workoutSessionID
        self.workoutDate = workoutDate
        self.exerciseSlug = exerciseSlug
        self.setType = setType
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.rpe = rpe
        self.isCompleted = isCompleted
    }
}

public struct ExercisePRSnapshot: Sendable, Equatable {
    public let heaviestWeightKg: Double
    public let bestEstimated1RMKg: Double
    public let mostReps: Int
    public let bestSetVolumeKg: Double
    public let bestSessionVolumeKg: Double

    public init(
        heaviestWeightKg: Double,
        bestEstimated1RMKg: Double,
        mostReps: Int,
        bestSetVolumeKg: Double,
        bestSessionVolumeKg: Double
    ) {
        self.heaviestWeightKg = heaviestWeightKg
        self.bestEstimated1RMKg = bestEstimated1RMKg
        self.mostReps = mostReps
        self.bestSetVolumeKg = bestSetVolumeKg
        self.bestSessionVolumeKg = bestSessionVolumeKg
    }
}

public struct PRBeatResult: Sendable, Equatable {
    public let beatWeight: Bool
    public let beatEstimated1RM: Bool
    public let beatReps: Bool
    public let beatVolume: Bool

    public var anyPR: Bool {
        beatWeight || beatEstimated1RM || beatReps || beatVolume
    }

    public init(beatWeight: Bool, beatEstimated1RM: Bool, beatReps: Bool, beatVolume: Bool) {
        self.beatWeight = beatWeight
        self.beatEstimated1RM = beatEstimated1RM
        self.beatReps = beatReps
        self.beatVolume = beatVolume
    }
}

public struct ExerciseHistoryPoint: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let date: Date
    public let bestEstimated1RMKg: Double
    public let topSetWeightKg: Double
    public let topSetReps: Int
    public let totalVolumeKg: Double
    public let totalReps: Int

    public init(
        id: UUID,
        date: Date,
        bestEstimated1RMKg: Double,
        topSetWeightKg: Double,
        topSetReps: Int,
        totalVolumeKg: Double,
        totalReps: Int
    ) {
        self.id = id
        self.date = date
        self.bestEstimated1RMKg = bestEstimated1RMKg
        self.topSetWeightKg = topSetWeightKg
        self.topSetReps = topSetReps
        self.totalVolumeKg = totalVolumeKg
        self.totalReps = totalReps
    }
}

public struct MuscleGroupWeeklyVolume: Identifiable, Sendable, Equatable {
    public let muscleGroup: MuscleGroup
    public let volumeKg: Double
    public let workingSets: Int

    public var id: MuscleGroup { muscleGroup }

    public init(muscleGroup: MuscleGroup, volumeKg: Double, workingSets: Int) {
        self.muscleGroup = muscleGroup
        self.volumeKg = volumeKg
        self.workingSets = workingSets
    }
}

public struct ScaledTemplateTarget: Sendable, Equatable {
    public let targetSets: Int
    public let targetRepsMin: Int
    public let targetRepsMax: Int
    public let targetDurationSeconds: Int

    public init(targetSets: Int, targetRepsMin: Int, targetRepsMax: Int, targetDurationSeconds: Int) {
        self.targetSets = targetSets
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.targetDurationSeconds = targetDurationSeconds
    }
}

public struct WorkoutCSVRow: Sendable, Equatable {
    public let workoutDate: Date
    public let workoutTitle: String
    public let workoutDurationSeconds: TimeInterval
    public let exerciseName: String
    public let muscleGroup: MuscleGroup
    public let setOrder: Int
    public let setType: SetType
    public let weightKg: Double
    public let reps: Int
    public let durationSeconds: Int
    public let rpe: Double?
    public let isPR: Bool

    public init(
        workoutDate: Date,
        workoutTitle: String,
        workoutDurationSeconds: TimeInterval,
        exerciseName: String,
        muscleGroup: MuscleGroup,
        setOrder: Int,
        setType: SetType,
        weightKg: Double,
        reps: Int,
        durationSeconds: Int,
        rpe: Double?,
        isPR: Bool
    ) {
        self.workoutDate = workoutDate
        self.workoutTitle = workoutTitle
        self.workoutDurationSeconds = workoutDurationSeconds
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.setOrder = setOrder
        self.setType = setType
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.rpe = rpe
        self.isPR = isPR
    }
}

public enum StrengthEngine {
    /// Epley 1RM formula: `weight * (1 + reps / 30)`. For 1 rep, returns `weight`.
    public static func estimated1RM(weightKg: Double, reps: Int) -> Double {
        guard weightKg.isFinite, weightKg > 0, reps > 0 else { return 0 }
        if reps == 1 { return weightKg }
        let clampedReps = min(36, reps)
        return weightKg * (1.0 + Double(clampedReps) / 30.0)
    }

    /// Working-set volume in kg (`weightKg * reps`); warm-up sets contribute 0.
    public static func setVolumeKg(weightKg: Double, reps: Int, setType: SetType) -> Double {
        guard setType.countsTowardPRAndVolume, weightKg.isFinite, weightKg > 0, reps > 0 else {
            return 0
        }
        return weightKg * Double(reps)
    }

    public static func totalWorkingVolumeKg(sets: [StrengthSetSnapshot]) -> Double {
        sets.reduce(0.0) { total, item in
            guard item.isCompleted else { return total }
            return total + setVolumeKg(weightKg: item.weightKg, reps: item.reps, setType: item.setType)
        }
    }

    public static func computeHistoricalPRs(sets: [StrengthSetSnapshot]) -> ExercisePRSnapshot {
        let working = sets.filter { $0.isCompleted && $0.setType.countsTowardPRAndVolume }
        guard !working.isEmpty else {
            return ExercisePRSnapshot(
                heaviestWeightKg: 0,
                bestEstimated1RMKg: 0,
                mostReps: 0,
                bestSetVolumeKg: 0,
                bestSessionVolumeKg: 0
            )
        }

        var heaviest = 0.0
        var best1RM = 0.0
        var mostReps = 0
        var bestSetVol = 0.0
        var sessionVolumes: [UUID: Double] = [:]

        for s in working {
            if s.weightKg > heaviest { heaviest = s.weightKg }
            let e1rm = estimated1RM(weightKg: s.weightKg, reps: s.reps)
            if e1rm > best1RM { best1RM = e1rm }
            if s.reps > mostReps { mostReps = s.reps }
            let vol = setVolumeKg(weightKg: s.weightKg, reps: s.reps, setType: s.setType)
            if vol > bestSetVol { bestSetVol = vol }
            sessionVolumes[s.workoutSessionID, default: 0.0] += vol
        }

        let bestSessionVol = sessionVolumes.values.max() ?? 0.0
        return ExercisePRSnapshot(
            heaviestWeightKg: heaviest,
            bestEstimated1RMKg: best1RM,
            mostReps: mostReps,
            bestSetVolumeKg: bestSetVol,
            bestSessionVolumeKg: bestSessionVol
        )
    }

    /// Evaluates whether a newly completed set beats any prior working-set PR for the same exercise.
    /// Requires at least one prior working set so the very first logged set ever establishes a baseline
    /// without spamming false PRs, OR if `requirePriorHistory` is false, marks any positive set.
    public static func evaluateSetPR(
        candidate: StrengthSetSnapshot,
        priorSets: [StrengthSetSnapshot],
        requirePriorHistory: Bool = true
    ) -> PRBeatResult {
        guard candidate.isCompleted, candidate.setType.countsTowardPRAndVolume else {
            return PRBeatResult(beatWeight: false, beatEstimated1RM: false, beatReps: false, beatVolume: false)
        }

        let relevantPrior = priorSets.filter {
            $0.exerciseSlug == candidate.exerciseSlug &&
            $0.id != candidate.id &&
            $0.isCompleted &&
            $0.setType.countsTowardPRAndVolume
        }
        if requirePriorHistory && relevantPrior.isEmpty {
            return PRBeatResult(beatWeight: false, beatEstimated1RM: false, beatReps: false, beatVolume: false)
        }

        let priorPR = computeHistoricalPRs(sets: relevantPrior)
        let cand1RM = estimated1RM(weightKg: candidate.weightKg, reps: candidate.reps)
        let candVol = setVolumeKg(weightKg: candidate.weightKg, reps: candidate.reps, setType: candidate.setType)

        return PRBeatResult(
            beatWeight: candidate.weightKg > 0 && candidate.weightKg > priorPR.heaviestWeightKg + 0.01,
            beatEstimated1RM: cand1RM > 0 && cand1RM > priorPR.bestEstimated1RMKg + 0.05,
            beatReps: candidate.reps > 0 && candidate.reps > priorPR.mostReps,
            beatVolume: candVol > 0 && candVol > priorPR.bestSetVolumeKg + 0.1
        )
    }

    public static func buildExerciseHistory(sets: [StrengthSetSnapshot]) -> [ExerciseHistoryPoint] {
        let working = sets.filter { $0.isCompleted && $0.setType.countsTowardPRAndVolume }
        let grouped = Dictionary(grouping: working, by: \.workoutSessionID)

        var points: [ExerciseHistoryPoint] = []
        for (sessionID, group) in grouped {
            guard let date = group.map(\.workoutDate).min() else { continue }
            var best1RM = 0.0
            var topWeight = 0.0
            var topReps = 0
            var vol = 0.0
            var repsSum = 0

            for s in group {
                let e1rm = estimated1RM(weightKg: s.weightKg, reps: s.reps)
                if e1rm > best1RM { best1RM = e1rm }
                if s.weightKg > topWeight || (abs(s.weightKg - topWeight) < 0.01 && s.reps > topReps) {
                    topWeight = s.weightKg
                    topReps = s.reps
                }
                vol += setVolumeKg(weightKg: s.weightKg, reps: s.reps, setType: s.setType)
                repsSum += max(0, s.reps)
            }

            points.append(
                ExerciseHistoryPoint(
                    id: sessionID,
                    date: date,
                    bestEstimated1RMKg: best1RM,
                    topSetWeightKg: topWeight,
                    topSetReps: topReps,
                    totalVolumeKg: vol,
                    totalReps: repsSum
                )
            )
        }

        return points.sorted { $0.date < $1.date }
    }

    public static func weeklyVolumeByMuscleGroup(
        entries: [(muscleGroup: MuscleGroup, set: StrengthSetSnapshot)],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [MuscleGroupWeeklyVolume] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return []
        }

        var volumeMap: [MuscleGroup: Double] = [:]
        var setsMap: [MuscleGroup: Int] = [:]

        for item in entries {
            let s = item.set
            guard s.isCompleted,
                  s.setType.countsTowardPRAndVolume,
                  s.workoutDate >= weekInterval.start,
                  s.workoutDate < weekInterval.end else {
                continue
            }
            let vol = setVolumeKg(weightKg: s.weightKg, reps: s.reps, setType: s.setType)
            volumeMap[item.muscleGroup, default: 0.0] += vol
            setsMap[item.muscleGroup, default: 0] += 1
        }

        return MuscleGroup.allCases.compactMap { group in
            let setCount = setsMap[group] ?? 0
            guard setCount > 0 else { return nil }
            return MuscleGroupWeeklyVolume(
                muscleGroup: group,
                volumeKg: volumeMap[group] ?? 0.0,
                workingSets: setCount
            )
        }.sorted { lhs, rhs in
            if lhs.volumeKg != rhs.volumeKg { return lhs.volumeKg > rhs.volumeKg }
            return lhs.workingSets > rhs.workingSets
        }
    }

    /// Scales a template item's sets/reps/duration cleanly (e.g. 0.75x deload, 1.0x standard, 1.25x overload).
    public static func scaleTemplateTarget(
        targetSets: Int,
        targetRepsMin: Int,
        targetRepsMax: Int,
        targetDurationSeconds: Int,
        factor: Double
    ) -> ScaledTemplateTarget {
        let clamped = min(2.0, max(0.5, factor))
        let newSets = max(1, Int((Double(max(1, targetSets)) * clamped).rounded()))
        let newMin = targetRepsMin > 0 ? max(1, Int((Double(targetRepsMin) * clamped).rounded())) : 0
        let newMax = targetRepsMax > 0 ? max(newMin, Int((Double(targetRepsMax) * clamped).rounded())) : 0
        let newDur = targetDurationSeconds > 0 ? max(10, Int((Double(targetDurationSeconds) * clamped).rounded())) : 0
        return ScaledTemplateTarget(
            targetSets: newSets,
            targetRepsMin: newMin,
            targetRepsMax: newMax,
            targetDurationSeconds: newDur
        )
    }

    public static func exportWorkoutsCSV(rows: [WorkoutCSVRow], weightUnit: WeightUnit) -> Data {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let u = weightUnit.symbol

        var lines: [String] = [
            "WorkoutDate,WorkoutTitle,WorkoutDuration(s),Exercise,MuscleGroup,SetOrder,SetType,Weight(\(u)),Reps,SetDuration(s),RPE,Est1RM(\(u)),Volume(\(u)),PR"
        ]

        for row in rows {
            let weightDisplay = weightUnit.fromKilograms(row.weightKg)
            let est1RM = weightUnit.fromKilograms(estimated1RM(weightKg: row.weightKg, reps: row.reps))
            let vol = weightUnit.fromKilograms(setVolumeKg(weightKg: row.weightKg, reps: row.reps, setType: row.setType))

            let fields: [String] = [
                iso.string(from: row.workoutDate),
                row.workoutTitle,
                String(format: "%.0f", row.workoutDurationSeconds),
                row.exerciseName,
                row.muscleGroup.displayName,
                "\(row.setOrder)",
                row.setType.displayName,
                String(format: "%.1f", weightDisplay),
                "\(row.reps)",
                "\(row.durationSeconds)",
                row.rpe.map { String(format: "%.1f", $0) } ?? "",
                String(format: "%.1f", est1RM),
                String(format: "%.1f", vol),
                row.isPR ? "YES" : ""
            ]
            lines.append(fields.map(escapeCSV).joined(separator: ","))
        }

        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
