import Foundation
import XCTest
@testable import TrackerCore

final class DataSafetyV2Tests: XCTestCase {
    func testV1BackupJSONDecodesCleanlyIntoV2Envelope() throws {
        let v1JSON = """
        {
          "activities": [],
          "appVersion": "1.0.0",
          "exportedAt": "2026-11-25T20:00:00Z",
          "gear": [],
          "goals": [],
          "routes": [],
          "schemaVersion": 1,
          "sections": [],
          "settings": {
            "audioCuesEnabled": true,
            "autoPauseEnabled": true,
            "elevationHysteresisMeters": 3.0,
            "featureFlags": {
              "barometricAltimeter": false,
              "bleHeartRate": false,
              "personalHeatmap": false,
              "personalSections": false
            },
            "hapticsEnabled": true,
            "maxHorizontalAccuracyMeters": 30.0,
            "privacyHideRadiusMeters": 200.0,
            "unitSystem": "metric",
            "userWeightKg": 72.0
          }
        }
        """

        let decoded = try BackupCodec.decode(Data(v1JSON.utf8))
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.appVersion, "1.0.0")
        XCTAssertEqual(decoded.settings.userWeightKg, 72.0, accuracy: 0.01)
        XCTAssertNil(decoded.settings.weightUnit)
        XCTAssertTrue(decoded.customExercises.isEmpty)
        XCTAssertTrue(decoded.workoutSessions.isEmpty)
        XCTAssertTrue(decoded.workoutTemplates.isEmpty)
    }

    func testV2BackupRoundTripIncludesFitnessEntities() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let customEx = BackupCustomExerciseRecord(
            id: UUID(),
            slug: "custom-landmine-press",
            name: "Landmine Press",
            muscleGroupRaw: "shoulders",
            primaryMusclesCSV: "anterior delts",
            secondaryMusclesCSV: "triceps,upper chest",
            equipmentCSV: "barbell",
            mechanicRaw: "compound",
            difficultyRaw: "intermediate",
            trackingTypeRaw: "weightReps",
            instructionsText: "Brace core\nPress barbell upward at an angle",
            tips: "Keep ribs stacked",
            commonMistakes: "Leaning back",
            createdAt: now
        )
        let sessionID = UUID()
        let entryID = UUID()
        let templateID = UUID()
        let envelope = BackupEnvelope(
            schemaVersion: BackupEnvelope.currentSchemaVersion,
            exportedAt: now,
            appVersion: "1.1",
            settings: BackupSettings(
                unitSystem: .metric,
                featureFlags: FeatureFlags(),
                autoPauseEnabled: true,
                audioCuesEnabled: true,
                hapticsEnabled: true,
                maxHorizontalAccuracyMeters: 30,
                elevationHysteresisMeters: 3,
                userWeightKg: 75,
                privacyHideRadiusMeters: 200,
                weightUnit: .lb,
                keepScreenAwakeWhileRecording: true,
                keepScreenAwakeDuringWorkout: false,
                selectedVoiceIdentifier: "com.apple.voice.enhanced.en-US.Samantha",
                speechRate: 0.47,
                speechPitch: 1.0,
                speechVolume: 0.9,
                cueEveryUnitEnabled: true,
                cueEveryNMinutes: 5,
                cueOnLapEnabled: true,
                cueOnPauseResumeEnabled: true,
                cueOnGoalReachedEnabled: true,
                defaultRestSeconds: 90
            ),
            activities: [],
            gear: [],
            goals: [],
            routes: [],
            sections: [],
            customExercises: [customEx],
            exercisePreferences: [
                BackupExercisePreferenceRecord(
                    exerciseSlug: "barbell-back-squat",
                    isFavorite: true,
                    personalNotes: "High bar stance",
                    defaultRestSeconds: 120,
                    updatedAt: now
                )
            ],
            workoutSessions: [
                BackupWorkoutSessionRecord(
                    id: sessionID,
                    title: "Push Day",
                    notes: "Felt strong",
                    startDate: now,
                    endDate: now.addingTimeInterval(2400),
                    durationSeconds: 2400,
                    isCompleted: true,
                    templateID: templateID,
                    linkedActivityID: nil,
                    totalVolumeKg: 4200,
                    completedSetCount: 12,
                    exerciseCount: 4
                )
            ],
            workoutExerciseEntries: [
                BackupWorkoutExerciseEntryRecord(
                    id: entryID,
                    workoutSessionID: sessionID,
                    exerciseSlug: "custom-landmine-press",
                    exerciseNameSnapshot: "Landmine Press",
                    muscleGroupRaw: "shoulders",
                    trackingTypeRaw: "weightReps",
                    orderIndex: 0,
                    restSeconds: 90,
                    notes: ""
                )
            ],
            setEntries: [
                BackupSetEntryRecord(
                    id: UUID(),
                    workoutSessionID: sessionID,
                    workoutExerciseEntryID: entryID,
                    exerciseSlug: "custom-landmine-press",
                    orderIndex: 0,
                    setTypeRaw: "normal",
                    weightKg: 40,
                    reps: 10,
                    durationSeconds: 0,
                    rpe: 8.0,
                    isCompleted: true,
                    completedAt: now.addingTimeInterval(300),
                    isPRWeight: true,
                    isPREstimated1RM: true,
                    isPRReps: false,
                    isPRVolume: true
                )
            ],
            workoutTemplates: [
                BackupWorkoutTemplateRecord(
                    id: templateID,
                    name: "Push Day",
                    notes: "Chest and shoulders",
                    isBuiltIn: true,
                    builtInKey: "push-day",
                    createdAt: now,
                    updatedAt: now
                )
            ],
            workoutTemplateItems: [
                BackupWorkoutTemplateItemRecord(
                    id: UUID(),
                    templateID: templateID,
                    exerciseSlug: "custom-landmine-press",
                    exerciseNameSnapshot: "Landmine Press",
                    orderIndex: 0,
                    targetSets: 3,
                    targetRepsMin: 8,
                    targetRepsMax: 12,
                    targetDurationSeconds: 0,
                    defaultRestSeconds: 90,
                    notes: ""
                )
            ]
        )

        let data = try BackupCodec.encode(envelope)
        let decoded = try BackupCodec.decode(data)
        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.customExercises.count, 1)
        XCTAssertEqual(decoded.exercisePreferences.count, 1)
        XCTAssertEqual(decoded.workoutSessions.count, 1)
        XCTAssertEqual(decoded.workoutExerciseEntries.count, 1)
        XCTAssertEqual(decoded.setEntries.count, 1)
        XCTAssertEqual(decoded.workoutTemplates.count, 1)
        XCTAssertEqual(decoded.workoutTemplateItems.count, 1)
        XCTAssertEqual(decoded.settings.weightUnit, .lb)
        XCTAssertEqual(decoded.settings.selectedVoiceIdentifier, "com.apple.voice.enhanced.en-US.Samantha")
    }

    func testWeightUnitAndSessionGoalProgress() {
        let lb = WeightUnit.lb.fromKilograms(100.0)
        XCTAssertEqual(lb, 220.462, accuracy: 0.01)
        XCTAssertEqual(WeightUnit.lb.toKilograms(lb), 100.0, accuracy: 0.01)
        XCTAssertEqual(RunFormatter.weight(kg: 60.0, unit: .kg), "60 kg")

        let now = Date()
        let strength = ActivityStatsInput(
            id: UUID(),
            title: "Leg Day",
            activityType: .strength,
            startDate: now,
            movingTime: 2700,
            distanceMeters: 0,
            elevationGainMeters: 0,
            effortScore: 38,
            estimatedCalories: 260
        )
        let sessions = StatsAggregator.goalProgress(
            activities: [strength],
            periodRaw: "weekly",
            metricRaw: "sessions",
            activityTypeFilter: .strength,
            referenceDate: now
        )
        XCTAssertEqual(sessions, 1.0, accuracy: 0.001)
        XCTAssertFalse(ActivityType.strength.isGPSActivity)
    }
}
