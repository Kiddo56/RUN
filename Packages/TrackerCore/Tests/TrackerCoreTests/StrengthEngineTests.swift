import Foundation
import XCTest
@testable import TrackerCore

final class StrengthEngineTests: XCTestCase {
    func testEpleyEstimated1RMAndVolumeIgnoreWarmUps() {
        XCTAssertEqual(StrengthEngine.estimated1RM(weightKg: 100, reps: 1), 100, accuracy: 0.01)
        XCTAssertEqual(StrengthEngine.estimated1RM(weightKg: 100, reps: 10), 133.33, accuracy: 0.1)
        XCTAssertEqual(StrengthEngine.estimated1RM(weightKg: 0, reps: 10), 0)

        XCTAssertEqual(StrengthEngine.setVolumeKg(weightKg: 60, reps: 10, setType: .warmUp), 0)
        XCTAssertEqual(StrengthEngine.setVolumeKg(weightKg: 80, reps: 8, setType: .normal), 640, accuracy: 0.01)
        XCTAssertEqual(StrengthEngine.setVolumeKg(weightKg: 70, reps: 10, setType: .drop), 700, accuracy: 0.01)
    }

    func testPRDetectionAndExerciseHistorySeries() {
        let s1 = UUID()
        let s2 = UUID()
        let t1 = Date(timeIntervalSince1970: 1_700_000_000)
        let t2 = t1.addingTimeInterval(86_400 * 3)

        let prior = [
            StrengthSetSnapshot(id: UUID(), workoutSessionID: s1, workoutDate: t1, exerciseSlug: "barbell-back-squat", setType: .warmUp, weightKg: 60, reps: 10),
            StrengthSetSnapshot(id: UUID(), workoutSessionID: s1, workoutDate: t1, exerciseSlug: "barbell-back-squat", setType: .normal, weightKg: 100, reps: 5)
        ]

        let newPRSet = StrengthSetSnapshot(
            id: UUID(),
            workoutSessionID: s2,
            workoutDate: t2,
            exerciseSlug: "barbell-back-squat",
            setType: .normal,
            weightKg: 105,
            reps: 6
        )

        let result = StrengthEngine.evaluateSetPR(candidate: newPRSet, priorSets: prior)
        XCTAssertTrue(result.anyPR)
        XCTAssertTrue(result.beatWeight)
        XCTAssertTrue(result.beatEstimated1RM)
        XCTAssertTrue(result.beatReps)
        XCTAssertTrue(result.beatVolume)

        let history = StrengthEngine.buildExerciseHistory(sets: prior + [newPRSet])
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].topSetWeightKg, 100, accuracy: 0.01)
        XCTAssertEqual(history[1].topSetWeightKg, 105, accuracy: 0.01)
        XCTAssertGreaterThan(history[1].bestEstimated1RMKg, history[0].bestEstimated1RMKg)
    }

    func testWeeklyVolumeTemplateScalingAndCSVExport() {
        let now = Date()
        let setA = StrengthSetSnapshot(id: UUID(), workoutSessionID: UUID(), workoutDate: now, exerciseSlug: "bench", setType: .normal, weightKg: 80, reps: 8)
        let setB = StrengthSetSnapshot(id: UUID(), workoutSessionID: UUID(), workoutDate: now, exerciseSlug: "row", setType: .normal, weightKg: 60, reps: 10)
        let weekly = StrengthEngine.weeklyVolumeByMuscleGroup(
            entries: [(.chest, setA), (.back, setB)],
            referenceDate: now
        )
        XCTAssertEqual(weekly.count, 2)
        XCTAssertEqual(weekly.first?.muscleGroup, .chest)
        XCTAssertEqual(weekly.first?.volumeKg ?? 0, 640, accuracy: 0.01)

        let scaled = StrengthEngine.scaleTemplateTarget(
            targetSets: 4,
            targetRepsMin: 8,
            targetRepsMax: 12,
            targetDurationSeconds: 0,
            factor: 0.75
        )
        XCTAssertEqual(scaled.targetSets, 3)
        XCTAssertEqual(scaled.targetRepsMin, 6)
        XCTAssertEqual(scaled.targetRepsMax, 9)

        let csvData = StrengthEngine.exportWorkoutsCSV(
            rows: [
                WorkoutCSVRow(
                    workoutDate: now,
                    workoutTitle: "Push Day",
                    workoutDurationSeconds: 2400,
                    exerciseName: "Barbell Bench Press",
                    muscleGroup: .chest,
                    setOrder: 1,
                    setType: .normal,
                    weightKg: 80,
                    reps: 8,
                    durationSeconds: 0,
                    rpe: 8.5,
                    isPR: true
                )
            ],
            weightUnit: .kg
        )
        let csvText = String(decoding: csvData, as: UTF8.self)
        XCTAssertTrue(csvText.contains("Barbell Bench Press"))
        XCTAssertTrue(csvText.contains("Push Day"))
        XCTAssertTrue(csvText.contains(",YES"))
    }
}
