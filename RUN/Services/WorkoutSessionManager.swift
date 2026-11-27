import Foundation
import Observation
import SwiftData
import TrackerCore

@MainActor
@Observable
final class WorkoutSessionManager {
    private(set) var activeSessionID: UUID?
    private(set) var pendingRecoverySessionID: UUID?
    private(set) var elapsedSeconds: TimeInterval = 0
    var isPresentingActiveWorkout = false

    // Rest timer state
    private(set) var restRemainingSeconds: Int = 0
    private(set) var restTotalSeconds: Int = 0
    private(set) var restExerciseName: String?
    var isRestTimerActive: Bool { restRemainingSeconds > 0 }

    private let haptics = AudioHapticCueService()
    private var elapsedTask: Task<Void, Never>?
    private var restTask: Task<Void, Never>?
    private var activeStartDate: Date?
    private weak var activeSettings: AppSettingsStore?

    func checkForUnfinishedWorkout(modelContext: ModelContext) {
        guard activeSessionID == nil else { return }
        let sessions = (try? modelContext.fetch(FetchDescriptor<SDWorkoutSession>(sortBy: [SortDescriptor(\.startDate, order: .reverse)]))) ?? []
        if let unfinished = sessions.first(where: { !$0.isCompleted }) {
            pendingRecoverySessionID = unfinished.id
            DiagnosticsLogger.shared.log(.recovery, "Found unfinished strength workout '\(unfinished.title)'")
        } else {
            pendingRecoverySessionID = nil
        }
    }

    func startEmptyWorkout(
        title: String = "Strength Workout",
        modelContext: ModelContext,
        settings: AppSettingsStore
    ) -> SDWorkoutSession {
        let now = Date()
        let session = SDWorkoutSession(
            title: title,
            startDate: now,
            isCompleted: false
        )
        modelContext.insert(session)
        try? modelContext.save()
        attachSession(session, settings: settings)
        DiagnosticsLogger.shared.log(.recording, "Started empty strength workout \(session.id)")
        return session
    }

    func startWorkout(
        from template: SDWorkoutTemplate,
        scaleFactor: Double = 1.0,
        modelContext: ModelContext,
        settings: AppSettingsStore
    ) -> SDWorkoutSession {
        let now = Date()
        let session = SDWorkoutSession(
            title: template.name,
            notes: template.notes,
            startDate: now,
            isCompleted: false,
            templateID: template.id
        )
        modelContext.insert(session)

        let allItems = ((try? modelContext.fetch(FetchDescriptor<SDWorkoutTemplateItem>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? [])
            .filter { $0.templateID == template.id }
        let customExercises = (try? modelContext.fetch(FetchDescriptor<SDCustomExercise>())) ?? []
        let prefs = (try? modelContext.fetch(FetchDescriptor<SDExercisePreference>())) ?? []
        let prefMap = Dictionary(uniqueKeysWithValues: prefs.map { ($0.exerciseSlug, $0) })

        for (idx, item) in allItems.enumerated() {
            let scaled = StrengthEngine.scaleTemplateTarget(
                targetSets: item.targetSets,
                targetRepsMin: item.targetRepsMin,
                targetRepsMax: item.targetRepsMax,
                targetDurationSeconds: item.targetDurationSeconds,
                factor: scaleFactor
            )
            let ex = ExerciseCatalogService.shared.exercise(forSlug: item.exerciseSlug, custom: customExercises)
            let prefRest = prefMap[item.exerciseSlug]?.defaultRestSeconds ?? 0
            let rest = prefRest > 0 ? prefRest : (item.defaultRestSeconds > 0 ? item.defaultRestSeconds : settings.defaultRestSeconds)

            let entry = SDWorkoutExerciseEntry(
                workoutSessionID: session.id,
                exerciseSlug: item.exerciseSlug,
                exerciseNameSnapshot: ex?.name ?? item.exerciseNameSnapshot,
                muscleGroupRaw: ex?.muscleGroup.rawValue ?? MuscleGroup.fullBody.rawValue,
                trackingTypeRaw: ex?.trackingType.rawValue ?? ExerciseTrackingType.weightReps.rawValue,
                orderIndex: idx,
                restSeconds: rest
            )
            modelContext.insert(entry)

            let previous = previousWorkingSets(forSlug: item.exerciseSlug, excludingSessionID: session.id, modelContext: modelContext)
            for sIdx in 0..<scaled.targetSets {
                let prevMatch = sIdx < previous.count ? previous[sIdx] : previous.last
                let setEntry = SDSetEntry(
                    workoutSessionID: session.id,
                    workoutExerciseEntryID: entry.id,
                    exerciseSlug: item.exerciseSlug,
                    orderIndex: sIdx,
                    setTypeRaw: SetType.normal.rawValue,
                    weightKg: prevMatch?.weightKg ?? 0,
                    reps: prevMatch?.reps ?? (scaled.targetRepsMin > 0 ? scaled.targetRepsMin : 10),
                    durationSeconds: prevMatch?.durationSeconds ?? (scaled.targetDurationSeconds > 0 ? scaled.targetDurationSeconds : 30),
                    isCompleted: false
                )
                modelContext.insert(setEntry)
            }
        }

        session.exerciseCount = allItems.count
        try? modelContext.save()
        attachSession(session, settings: settings)
        DiagnosticsLogger.shared.log(.recording, "Started workout from template '\(template.name)' (scale \(scaleFactor)x)")
        return session
    }

    func resumePendingWorkout(modelContext: ModelContext, settings: AppSettingsStore) {
        guard let id = pendingRecoverySessionID else { return }
        let sessions = (try? modelContext.fetch(FetchDescriptor<SDWorkoutSession>())) ?? []
        guard let session = sessions.first(where: { $0.id == id && !$0.isCompleted }) else {
            pendingRecoverySessionID = nil
            return
        }
        pendingRecoverySessionID = nil
        attachSession(session, settings: settings)
        DiagnosticsLogger.shared.log(.recovery, "Resumed unfinished workout '\(session.title)'")
    }

    func discardPendingWorkout(modelContext: ModelContext) {
        guard let id = pendingRecoverySessionID else { return }
        deleteWorkoutCascade(sessionID: id, modelContext: modelContext)
        pendingRecoverySessionID = nil
        DiagnosticsLogger.shared.log(.recovery, "Discarded unfinished workout")
    }

    func addExercise(
        _ exercise: CatalogExercise,
        toSession session: SDWorkoutSession,
        modelContext: ModelContext,
        settings: AppSettingsStore
    ) {
        let existingEntries = ((try? modelContext.fetch(FetchDescriptor<SDWorkoutExerciseEntry>())) ?? [])
            .filter { $0.workoutSessionID == session.id }
        let nextOrder = (existingEntries.map(\.orderIndex).max() ?? -1) + 1

        let prefs = (try? modelContext.fetch(FetchDescriptor<SDExercisePreference>())) ?? []
        let prefRest = prefs.first(where: { $0.exerciseSlug == exercise.id })?.defaultRestSeconds ?? 0
        let rest = prefRest > 0 ? prefRest : settings.defaultRestSeconds

        let entry = SDWorkoutExerciseEntry(
            workoutSessionID: session.id,
            exerciseSlug: exercise.id,
            exerciseNameSnapshot: exercise.name,
            muscleGroupRaw: exercise.muscleGroup.rawValue,
            trackingTypeRaw: exercise.trackingType.rawValue,
            orderIndex: nextOrder,
            restSeconds: rest
        )
        modelContext.insert(entry)

        let prev = previousWorkingSets(forSlug: exercise.id, excludingSessionID: session.id, modelContext: modelContext)
        let firstSet = SDSetEntry(
            workoutSessionID: session.id,
            workoutExerciseEntryID: entry.id,
            exerciseSlug: exercise.id,
            orderIndex: 0,
            setTypeRaw: SetType.normal.rawValue,
            weightKg: prev.first?.weightKg ?? 0,
            reps: prev.first?.reps ?? (exercise.trackingType == .timeOnly ? 0 : 10),
            durationSeconds: prev.first?.durationSeconds ?? (exercise.trackingType == .timeOnly ? 45 : 0),
            isCompleted: false
        )
        modelContext.insert(firstSet)
        session.exerciseCount = existingEntries.count + 1
        try? modelContext.save()
    }

    func addSet(
        to entry: SDWorkoutExerciseEntry,
        modelContext: ModelContext
    ) {
        let sets = ((try? modelContext.fetch(FetchDescriptor<SDSetEntry>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? [])
            .filter { $0.workoutExerciseEntryID == entry.id }
        let last = sets.last
        let next = SDSetEntry(
            workoutSessionID: entry.workoutSessionID,
            workoutExerciseEntryID: entry.id,
            exerciseSlug: entry.exerciseSlug,
            orderIndex: (last?.orderIndex ?? -1) + 1,
            setTypeRaw: SetType.normal.rawValue,
            weightKg: last?.weightKg ?? 0,
            reps: last?.reps ?? (entry.trackingTypeRaw == ExerciseTrackingType.timeOnly.rawValue ? 0 : 10),
            durationSeconds: last?.durationSeconds ?? (entry.trackingTypeRaw == ExerciseTrackingType.timeOnly.rawValue ? 45 : 0),
            isCompleted: false
        )
        modelContext.insert(next)
        try? modelContext.save()
    }

    func toggleSetCompletion(
        _ setEntry: SDSetEntry,
        entry: SDWorkoutExerciseEntry,
        modelContext: ModelContext,
        settings: AppSettingsStore
    ) {
        let nowCompleting = !setEntry.isCompleted
        setEntry.isCompleted = nowCompleting
        setEntry.completedAt = nowCompleting ? Date() : nil

        if nowCompleting {
            haptics.splitMilestone(hapticsEnabled: settings.hapticsEnabled)
            let priorSnapshots = historicalCompletedSetSnapshots(
                forSlug: setEntry.exerciseSlug,
                excludingSetID: setEntry.id,
                modelContext: modelContext
            )
            let candidate = StrengthSetSnapshot(
                id: setEntry.id,
                workoutSessionID: setEntry.workoutSessionID,
                workoutDate: Date(),
                exerciseSlug: setEntry.exerciseSlug,
                setType: SetType(rawValue: setEntry.setTypeRaw) ?? .normal,
                weightKg: setEntry.weightKg,
                reps: setEntry.reps,
                durationSeconds: setEntry.durationSeconds,
                rpe: setEntry.rpe,
                isCompleted: true
            )
            let pr = StrengthEngine.evaluateSetPR(candidate: candidate, priorSets: priorSnapshots, requirePriorHistory: true)
            setEntry.isPRWeight = pr.beatWeight
            setEntry.isPREstimated1RM = pr.beatEstimated1RM
            setEntry.isPRReps = pr.beatReps
            setEntry.isPRVolume = pr.beatVolume

            if pr.anyPR {
                SpeechService.shared.announceWorkoutPR(exerciseName: entry.exerciseNameSnapshot, settings: settings)
            }

            if entry.restSeconds > 0 {
                startRestTimer(seconds: entry.restSeconds, exerciseName: entry.exerciseNameSnapshot, settings: settings)
            }
        } else {
            setEntry.isPRWeight = false
            setEntry.isPREstimated1RM = false
            setEntry.isPRReps = false
            setEntry.isPRVolume = false
        }

        try? modelContext.save()
    }

    func startRestTimer(seconds: Int, exerciseName: String?, settings: AppSettingsStore) {
        activeSettings = settings
        restTask?.cancel()
        let clamped = max(5, seconds)
        restTotalSeconds = clamped
        restRemainingSeconds = clamped
        restExerciseName = exerciseName

        restTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { break }
                if self.restRemainingSeconds > 1 {
                    self.restRemainingSeconds -= 1
                } else {
                    self.restRemainingSeconds = 0
                    self.restTotalSeconds = 0
                    let nextName = self.restExerciseName
                    if let s = self.activeSettings {
                        self.haptics.countdownGo(hapticsEnabled: s.hapticsEnabled)
                        SpeechService.shared.announceRestTimerDone(nextExerciseName: nextName, settings: s)
                    }
                    break
                }
            }
        }
    }

    func adjustRestTimer(deltaSeconds: Int) {
        guard restRemainingSeconds > 0 else { return }
        let updated = max(5, restRemainingSeconds + deltaSeconds)
        restRemainingSeconds = updated
        if updated > restTotalSeconds {
            restTotalSeconds = updated
        }
    }

    func skipRestTimer() {
        restTask?.cancel()
        restTask = nil
        restRemainingSeconds = 0
        restTotalSeconds = 0
    }

    func finishWorkout(
        session: SDWorkoutSession,
        title: String,
        notes: String,
        modelContext: ModelContext,
        settings: AppSettingsStore
    ) {
        let now = Date()
        let duration = max(60, now.timeIntervalSince(session.startDate))
        let entries = ((try? modelContext.fetch(FetchDescriptor<SDWorkoutExerciseEntry>())) ?? [])
            .filter { $0.workoutSessionID == session.id }
        let sets = ((try? modelContext.fetch(FetchDescriptor<SDSetEntry>())) ?? [])
            .filter { $0.workoutSessionID == session.id }

        let completedSets = sets.filter(\.isCompleted)
        let snapshots = completedSets.map {
            StrengthSetSnapshot(
                id: $0.id,
                workoutSessionID: session.id,
                workoutDate: session.startDate,
                exerciseSlug: $0.exerciseSlug,
                setType: SetType(rawValue: $0.setTypeRaw) ?? .normal,
                weightKg: $0.weightKg,
                reps: $0.reps,
                durationSeconds: $0.durationSeconds,
                rpe: $0.rpe,
                isCompleted: true
            )
        }
        let totalVol = StrengthEngine.totalWorkingVolumeKg(sets: snapshots)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        session.title = cleanTitle.isEmpty ? "Strength Workout" : cleanTitle
        session.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        session.endDate = now
        session.durationSeconds = duration
        session.isCompleted = true
        session.totalVolumeKg = totalVol
        session.completedSetCount = completedSets.count
        session.exerciseCount = entries.count

        let effort = TrackAnalyzer.estimateEffortScore(
            activityType: .strength,
            movingTimeSeconds: duration,
            averageSpeedMPS: 0,
            averageHeartRate: nil
        )
        let estCals = TrackAnalyzer.estimateCalories(
            activityType: .strength,
            movingTimeSeconds: duration,
            distanceMeters: 0,
            elevationGainMeters: 0,
            weightKg: settings.userWeightKg
        )

        let existingActivitiesBefore = ((try? modelContext.fetch(FetchDescriptor<SDActivity>())) ?? []).map {
            ActivityStatsInput(
                id: $0.id,
                title: $0.title,
                activityType: $0.activityType,
                startDate: $0.startDate,
                movingTime: $0.movingTime,
                distanceMeters: $0.distanceMeters,
                elevationGainMeters: $0.elevationGainMeters,
                effortScore: $0.effortScore,
                estimatedCalories: $0.estimatedCalories,
                gearID: $0.gearID
            )
        }

        // Insert linked Strength SDActivity so it integrates seamlessly with Timeline, Calendar, Streaks & Goals!
        let linkedID = session.linkedActivityID ?? UUID()
        session.linkedActivityID = linkedID
        let linkedActivity = SDActivity(
            id: linkedID,
            activityType: .strength,
            startDate: session.startDate,
            endDate: now,
            movingTime: duration,
            elapsedTime: duration,
            distanceMeters: 0,
            elevationGainMeters: 0,
            effortScore: effort,
            estimatedCalories: estCals,
            title: session.title,
            notes: session.notes,
            source: "strength_workout",
            trackFileName: "",
            pointCount: 0
        )
        modelContext.insert(linkedActivity)
        try? modelContext.save()

        SpeechService.shared.announceWorkoutComplete(
            durationSeconds: duration,
            completedSets: completedSets.count,
            settings: settings
        )
        checkGoalsReachedAfterWorkout(
            before: existingActivitiesBefore,
            added: linkedActivity,
            modelContext: modelContext,
            settings: settings
        )
        DiagnosticsLogger.shared.log(
            .recording,
            "Finished strength workout '\(session.title)': \(completedSets.count) sets, \(Int(totalVol)) kg vol"
        )
        detachSession()
    }

    func discardActiveWorkout(modelContext: ModelContext) {
        if let id = activeSessionID {
            deleteWorkoutCascade(sessionID: id, modelContext: modelContext)
        }
        detachSession()
    }

    func deleteWorkoutCascade(sessionID: UUID, modelContext: ModelContext) {
        let sessions = (try? modelContext.fetch(FetchDescriptor<SDWorkoutSession>())) ?? []
        if let session = sessions.first(where: { $0.id == sessionID }) {
            if let linkedID = session.linkedActivityID {
                let acts = (try? modelContext.fetch(FetchDescriptor<SDActivity>())) ?? []
                if let act = acts.first(where: { $0.id == linkedID }) {
                    modelContext.delete(act)
                }
            }
            modelContext.delete(session)
        }
        for entry in ((try? modelContext.fetch(FetchDescriptor<SDWorkoutExerciseEntry>())) ?? []) where entry.workoutSessionID == sessionID {
            modelContext.delete(entry)
        }
        for set in ((try? modelContext.fetch(FetchDescriptor<SDSetEntry>())) ?? []) where set.workoutSessionID == sessionID {
            modelContext.delete(set)
        }
        try? modelContext.save()
    }

    func previousWorkingSets(
        forSlug slug: String,
        excludingSessionID: UUID,
        modelContext: ModelContext
    ) -> [SDSetEntry] {
        let sessions = ((try? modelContext.fetch(FetchDescriptor<SDWorkoutSession>(sortBy: [SortDescriptor(\.startDate, order: .reverse)]))) ?? [])
            .filter { $0.isCompleted && $0.id != excludingSessionID }
        let allSets = ((try? modelContext.fetch(FetchDescriptor<SDSetEntry>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? [])
            .filter { $0.exerciseSlug == slug && $0.isCompleted && $0.setTypeRaw != SetType.warmUp.rawValue }

        for session in sessions {
            let matching = allSets.filter { $0.workoutSessionID == session.id }
            if !matching.isEmpty {
                return matching
            }
        }
        return []
    }

    private func historicalCompletedSetSnapshots(
        forSlug slug: String,
        excludingSetID: UUID,
        modelContext: ModelContext
    ) -> [StrengthSetSnapshot] {
        let sessions = (try? modelContext.fetch(FetchDescriptor<SDWorkoutSession>())) ?? []
        let dateMap = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.startDate) })
        let sets = ((try? modelContext.fetch(FetchDescriptor<SDSetEntry>())) ?? [])
            .filter { $0.exerciseSlug == slug && $0.id != excludingSetID && $0.isCompleted }

        return sets.map {
            StrengthSetSnapshot(
                id: $0.id,
                workoutSessionID: $0.workoutSessionID,
                workoutDate: dateMap[$0.workoutSessionID] ?? ($0.completedAt ?? Date()),
                exerciseSlug: $0.exerciseSlug,
                setType: SetType(rawValue: $0.setTypeRaw) ?? .normal,
                weightKg: $0.weightKg,
                reps: $0.reps,
                durationSeconds: $0.durationSeconds,
                rpe: $0.rpe,
                isCompleted: true
            )
        }
    }

    private func attachSession(_ session: SDWorkoutSession, settings: AppSettingsStore) {
        activeSessionID = session.id
        activeStartDate = session.startDate
        activeSettings = settings
        elapsedSeconds = max(0, Date().timeIntervalSince(session.startDate))
        isPresentingActiveWorkout = true
        ScreenAwakeController.shared.setWorkoutAwake(settings.keepScreenAwakeDuringWorkout)

        elapsedTask?.cancel()
        elapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, let start = self.activeStartDate else { break }
                self.elapsedSeconds = max(0, Date().timeIntervalSince(start))
            }
        }
    }

    func detachSession() {
        elapsedTask?.cancel()
        elapsedTask = nil
        skipRestTimer()
        activeSessionID = nil
        activeStartDate = nil
        elapsedSeconds = 0
        isPresentingActiveWorkout = false
        ScreenAwakeController.shared.setWorkoutAwake(false)
    }

    private func checkGoalsReachedAfterWorkout(
        before: [ActivityStatsInput],
        added: SDActivity,
        modelContext: ModelContext,
        settings: AppSettingsStore
    ) {
        guard settings.cueOnGoalReachedEnabled,
              let goals = try? modelContext.fetch(FetchDescriptor<SDGoal>()),
              !goals.isEmpty else {
            return
        }
        let addedInput = ActivityStatsInput(
            id: added.id,
            title: added.title,
            activityType: added.activityType,
            startDate: added.startDate,
            movingTime: added.movingTime,
            distanceMeters: 0,
            elevationGainMeters: 0,
            effortScore: added.effortScore,
            estimatedCalories: added.estimatedCalories,
            gearID: nil
        )
        let after = before + [addedInput]
        for goal in goals where goal.targetValue > 0 {
            let filter = goal.activityTypeRaw.flatMap { ActivityType(rawValue: $0) }
            let prevVal = StatsAggregator.goalProgress(
                activities: before,
                periodRaw: goal.periodRaw,
                metricRaw: goal.metricRaw,
                activityTypeFilter: filter
            )
            let nextVal = StatsAggregator.goalProgress(
                activities: after,
                periodRaw: goal.periodRaw,
                metricRaw: goal.metricRaw,
                activityTypeFilter: filter
            )
            if prevVal < goal.targetValue && nextVal >= goal.targetValue {
                SpeechService.shared.announceGoalReached(goalTitle: goal.title, settings: settings)
                break
            }
        }
    }
}
