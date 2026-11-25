import XCTest
@testable import TrackerCore

final class Phase3StatsTests: XCTestCase {
    private func loadFixture(_ name: String) throws -> [TrackPoint] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "gpx"))
        let data = try Data(contentsOf: url)
        return try BasicGPXReader.parseTrackPoints(from: data)
    }

    func testStatsAggregatorTotalsStreaksTrendsAndGoalProgress() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let refDate = Date(timeIntervalSince1970: 1_780_000_000) // arbitrary fixed day

        let inputs: [ActivityStatsInput] = [
            ActivityStatsInput(id: UUID(), title: "Today Run", activityType: .run, startDate: refDate, movingTime: 1800, distanceMeters: 6000, elevationGainMeters: 40, effortScore: 45, estimatedCalories: 350),
            ActivityStatsInput(id: UUID(), title: "Yesterday Ride", activityType: .ride, startDate: calendar.date(byAdding: .day, value: -1, to: refDate)!, movingTime: 3600, distanceMeters: 25000, elevationGainMeters: 210, effortScore: 70, estimatedCalories: 580),
            ActivityStatsInput(id: UUID(), title: "Two Days Ago", activityType: .walk, startDate: calendar.date(byAdding: .day, value: -2, to: refDate)!, movingTime: 1200, distanceMeters: 1500, elevationGainMeters: 10, effortScore: 15, estimatedCalories: 110),
            // Older 5-day streak 20 days prior
            ActivityStatsInput(id: UUID(), title: "Old 1", activityType: .run, startDate: calendar.date(byAdding: .day, value: -20, to: refDate)!, movingTime: 1500, distanceMeters: 4000, elevationGainMeters: 20, effortScore: 30, estimatedCalories: 260),
            ActivityStatsInput(id: UUID(), title: "Old 2", activityType: .run, startDate: calendar.date(byAdding: .day, value: -21, to: refDate)!, movingTime: 1500, distanceMeters: 4000, elevationGainMeters: 20, effortScore: 30, estimatedCalories: 260),
            ActivityStatsInput(id: UUID(), title: "Old 3", activityType: .run, startDate: calendar.date(byAdding: .day, value: -22, to: refDate)!, movingTime: 1500, distanceMeters: 4000, elevationGainMeters: 20, effortScore: 30, estimatedCalories: 260),
            ActivityStatsInput(id: UUID(), title: "Old 4", activityType: .run, startDate: calendar.date(byAdding: .day, value: -23, to: refDate)!, movingTime: 1500, distanceMeters: 4000, elevationGainMeters: 20, effortScore: 30, estimatedCalories: 260),
            ActivityStatsInput(id: UUID(), title: "Old 5", activityType: .run, startDate: calendar.date(byAdding: .day, value: -24, to: refDate)!, movingTime: 1500, distanceMeters: 4000, elevationGainMeters: 20, effortScore: 30, estimatedCalories: 260)
        ]

        let allTotals = StatsAggregator.totalsByType(inputs, timeframe: .allTime, referenceDate: refDate, calendar: calendar)
        XCTAssertEqual(allTotals.count, 3)
        XCTAssertEqual(allTotals.first?.activityType, .run) // 25 km total runs vs 25 km ride, tie or close -> check count
        XCTAssertEqual(allTotals.first(where: { $0.activityType == .run })?.count, 6)

        let streaks = StatsAggregator.streaks(activities: inputs, referenceDate: refDate, calendar: calendar)
        XCTAssertEqual(streaks.currentDayStreak, 3)
        XCTAssertEqual(streaks.longestDayStreak, 5)
        XCTAssertGreaterThanOrEqual(streaks.currentWeekStreak, 1)

        let weekBuckets = StatsAggregator.trendBuckets(activities: inputs, timeframe: .week, referenceDate: refDate, calendar: calendar)
        XCTAssertEqual(weekBuckets.count, 7)

        let fitnessSeries = StatsAggregator.fitnessFatigueTrend(activities: inputs, days: 30, referenceDate: refDate, calendar: calendar)
        XCTAssertEqual(fitnessSeries.count, 30)
        // Fatigue today should exceed fitness after recent consecutive workouts
        XCTAssertGreaterThan(fitnessSeries.last!.fatigue, fitnessSeries.last!.fitness)

        let runGoalDist = StatsAggregator.goalProgress(
            activities: inputs,
            periodRaw: "monthly",
            metricRaw: "distanceMeters",
            activityTypeFilter: .run,
            referenceDate: refDate,
            calendar: calendar
        )
        XCTAssertGreaterThanOrEqual(runGoalDist, 5000)
    }

    func testSlidingWindowPersonalRecordScanner() throws {
        // Synthetic 3km run: km 1 @ 360s, km 2 @ 210s (3:30/km), km 3 @ 360s
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        var points: [TrackPoint] = []
        let dlatPerM = 1.0 / 111195.0
        var cumTime = 0.0
        var cumDist = 0.0

        // 100 steps of 10m for km 1 (3.6s/10m -> 360s)
        for i in 0..<100 {
            points.append(TrackPoint(timestamp: t0.addingTimeInterval(cumTime), latitude: 37.77 + cumDist * dlatPerM, longitude: -122.41))
            if i < 99 { cumTime += 3.6; cumDist += 10.0 }
        }
        cumTime += 3.6; cumDist += 10.0
        // 100 steps of 10m for km 2 (2.1s/10m -> 210s)
        for i in 0..<100 {
            points.append(TrackPoint(timestamp: t0.addingTimeInterval(cumTime), latitude: 37.77 + cumDist * dlatPerM, longitude: -122.41))
            if i < 99 { cumTime += 2.1; cumDist += 10.0 }
        }
        cumTime += 2.1; cumDist += 10.0
        // 100 steps of 10m for km 3 (3.6s/10m -> 360s)
        for i in 0..<100 {
            points.append(TrackPoint(timestamp: t0.addingTimeInterval(cumTime), latitude: 37.77 + cumDist * dlatPerM, longitude: -122.41))
            if i < 99 { cumTime += 3.6; cumDist += 10.0 }
        }

        let fastest1K = try XCTUnwrap(PersonalRecordScanner.fastestDuration(forTargetMeters: 1000.0, in: points))
        XCTAssertEqual(fastest1K, 210.0, accuracy: 3.0)

        let steadyRun = try loadFixture("steady_run")
        let summary = TrackAnalyzer.summarize(points: steadyRun, activityType: .run)
        let input = ActivityStatsInput(
            id: UUID(),
            title: "Steady Run",
            activityType: .run,
            startDate: summary.startDate,
            movingTime: summary.movingTime,
            distanceMeters: summary.distanceMeters,
            elevationGainMeters: summary.elevationGainMeters,
            effortScore: summary.effortScore,
            estimatedCalories: summary.estimatedCalories
        )
        let records = PersonalRecordScanner.scanAll(activities: [(input: input, points: steadyRun)])
        XCTAssertNotNil(records.first(where: { $0.category == .fastest1K }))
        XCTAssertNotNil(records.first(where: { $0.category == .fastest1Mi }))
        XCTAssertNotNil(records.first(where: { $0.category == .fastest5K }))
        XCTAssertNil(records.first(where: { $0.category == .fastest10K }))
        XCTAssertNotNil(records.first(where: { $0.category == .longestDistance }))
        XCTAssertNotNil(records.first(where: { $0.category == .biggestClimb }))
    }

    func testTrackPrivacyTrimmerHidesFirstAndLast200Meters() throws {
        let steadyRun = try loadFixture("steady_run")
        let trimmed = TrackPrivacyTrimmer.trimEndpoints(points: steadyRun, hideMeters: 200.0)
        XCTAssertLessThan(trimmed.count, steadyRun.count)
        XCTAssertGreaterThan(trimmed.count, 50)

        let firstOriginal = steadyRun.first!
        let firstTrimmed = trimmed.first!
        let removedStartDist = GeoMath.distanceMeters(
            lat1: firstOriginal.latitude, lon1: firstOriginal.longitude,
            lat2: firstTrimmed.latitude, lon2: firstTrimmed.longitude
        )
        XCTAssertGreaterThanOrEqual(removedStartDist, 195.0)
    }
}
