import XCTest
@testable import TrackerCore

final class RecordingEngineTests: XCTestCase {
    private func loadFixture(_ name: String) throws -> [TrackPoint] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "gpx"))
        let data = try Data(contentsOf: url)
        return try BasicGPXReader.parseTrackPoints(from: data)
    }

    func testGPSFilterRejectsBadAccuracyStaleNonMonotonicSpeedJumpAndJitter() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var filter = GPSFilter(
            sessionStart: start,
            config: GPSFilterConfig(
                maxHorizontalAccuracyMeters: 30.0,
                maxStaleAgeSeconds: 15.0,
                minDistanceJitterMeters: 1.5,
                maxPlausibleSpeedMPS: 12.0
            )
        )

        // Invalid accuracy
        let badNeg = TrackPoint(timestamp: start, latitude: 37.77, longitude: -122.41, horizontalAccuracy: -1)
        if case .reject(.invalidAccuracy, .lost) = filter.evaluate(badNeg, referenceNow: start) {} else {
            XCTFail("Expected invalidAccuracy rejection")
        }

        // Accuracy > 30m
        let badAcc = TrackPoint(timestamp: start, latitude: 37.77, longitude: -122.41, horizontalAccuracy: 45)
        if case .reject(.accuracyTooLow, .poor) = filter.evaluate(badAcc, referenceNow: start) {} else {
            XCTFail("Expected accuracyTooLow rejection")
        }

        // Stale timestamp
        let stale = TrackPoint(timestamp: start, latitude: 37.77, longitude: -122.41, horizontalAccuracy: 5)
        if case .reject(.staleTimestamp, .lost) = filter.evaluate(stale, referenceNow: start.addingTimeInterval(30)) {} else {
            XCTFail("Expected staleTimestamp rejection")
        }

        // First valid fix
        let p0 = TrackPoint(timestamp: start, latitude: 37.7700, longitude: -122.4100, horizontalAccuracy: 6, speed: 3.0)
        if case let .accept(delta, _, quality) = filter.evaluate(p0, referenceNow: start) {
            XCTAssertEqual(delta, 0)
            XCTAssertEqual(quality, .excellent)
        } else {
            XCTFail("Expected first fix acceptance")
        }

        // Non-monotonic timestamp
        let back = TrackPoint(timestamp: start, latitude: 37.7701, longitude: -122.4100, horizontalAccuracy: 6, speed: 3.0)
        if case .reject(.nonMonotonicTimestamp, _) = filter.evaluate(back, referenceNow: start.addingTimeInterval(2)) {} else {
            XCTFail("Expected nonMonotonicTimestamp rejection")
        }

        // Impossible jump (> 12 m/s and > 25m)
        let jump = TrackPoint(timestamp: start.addingTimeInterval(2), latitude: 37.7800, longitude: -122.4100, horizontalAccuracy: 5, speed: 3.0)
        if case .reject(.impossibleSpeedJump, _) = filter.evaluate(jump, referenceNow: start.addingTimeInterval(2)) {} else {
            XCTFail("Expected impossibleSpeedJump rejection")
        }

        // Stationary jitter (< 1.5m and speed < 0.3)
        let jitter = TrackPoint(timestamp: start.addingTimeInterval(3), latitude: 37.770001, longitude: -122.410001, horizontalAccuracy: 5, speed: 0.1)
        if case .reject(.stationaryJitter, _) = filter.evaluate(jitter, referenceNow: start.addingTimeInterval(3)) {} else {
            XCTFail("Expected stationaryJitter rejection")
        }

        // Valid next point (~111m in 35s = ~3.17 m/s)
        let p1 = TrackPoint(timestamp: start.addingTimeInterval(35), latitude: 37.7710, longitude: -122.4100, horizontalAccuracy: 10, speed: 3.17)
        if case let .accept(delta, _, quality) = filter.evaluate(p1, referenceNow: start.addingTimeInterval(35)) {
            XCTAssertEqual(delta, 111.19, accuracy: 2.0)
            XCTAssertEqual(quality, .good)
        } else {
            XCTFail("Expected valid point acceptance")
        }
    }

    func testPaceSmootherWindowAndReset() {
        var smoother = PaceSmoother(windowSeconds: 10.0, minDistanceMeters: 5.0)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        for i in 0...10 {
            // 4 m/s -> 40m over 10s
            smoother.append(timestamp: t0.addingTimeInterval(Double(i)), cumulativeDistanceMeters: Double(i) * 4.0)
        }
        XCTAssertEqual(smoother.smoothedSpeedMPS, 4.0, accuracy: 0.05)
        XCTAssertEqual(smoother.smoothedPaceSecondsPerMeter, 0.25, accuracy: 0.01)

        smoother.reset()
        XCTAssertEqual(smoother.smoothedSpeedMPS, 0)
        XCTAssertEqual(smoother.smoothedPaceSecondsPerMeter, 0)
    }

    func testElevationEngineHysteresisIgnoresSmallJitter() {
        var engine = ElevationEngine(hysteresisMeters: 3.0)
        let altitudes = [100.0, 101.5, 99.2, 101.8, 100.4, 103.5, 102.0, 106.8, 103.2]
        for ele in altitudes {
            engine.ingest(altitudeMeters: ele, verticalAccuracy: 5.0)
        }
        // Only 100 -> 103.5 (+3.5), 103.5 -> 106.8 (+3.3) exceed +3m; 106.8 -> 103.2 (-3.6) exceeds -3m
        XCTAssertEqual(engine.elevationGainMeters, 6.8, accuracy: 0.01)
        XCTAssertEqual(engine.elevationLossMeters, 3.6, accuracy: 0.01)
    }

    func testMovingTimeEngineAutoPauseAndResume() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var moving = MovingTimeEngine(autoPauseEnabled: true, autoPauseSpeedThresholdMPS: 0.8, autoPauseDelaySeconds: 5.0)
        moving.start(at: start)

        for sec in 1...10 {
            XCTAssertEqual(moving.advance(to: start.addingTimeInterval(Double(sec)), speedMPS: 3.0), .none)
        }
        XCTAssertFalse(moving.isAutoPaused)
        XCTAssertEqual(moving.movingTime, 10.0, accuracy: 0.01)

        var sawPause = false
        for sec in 11...18 {
            if moving.advance(to: start.addingTimeInterval(Double(sec)), speedMPS: 0.1) == .didAutoPause {
                sawPause = true
            }
        }
        XCTAssertTrue(sawPause)
        XCTAssertTrue(moving.isAutoPaused)

        XCTAssertEqual(moving.advance(to: start.addingTimeInterval(25), speedMPS: 0.1), .none)
        XCTAssertEqual(moving.elapsedTime, 25.0, accuracy: 0.01)
        XCTAssertLessThan(moving.movingTime, 17.0)

        XCTAssertEqual(moving.advance(to: start.addingTimeInterval(26), speedMPS: 2.5), .didAutoResume)
        XCTAssertFalse(moving.isAutoPaused)
    }

    func testTrackBlobCodecRoundTripAndJournalResilience() throws {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        var points: [TrackPoint] = []
        points.reserveCapacity(120)
        for i in 0..<120 {
            let offset = Double(i)
            let hr: Double? = (i % 2 == 0) ? 155.0 : nil
            let pt = TrackPoint(
                timestamp: t0.addingTimeInterval(offset * 2.0),
                latitude: 37.77 + offset * 0.0001,
                longitude: -122.41 - offset * 0.0001,
                altitude: 15.0 + offset * 0.2,
                horizontalAccuracy: 5.5,
                verticalAccuracy: 8.0,
                speed: 3.2,
                course: 45.0,
                heartRate: hr,
                isPaused: i == 50
            )
            points.append(pt)
        }

        let encoded = try TrackBlobCodec.encode(points)
        XCTAssertLessThan(encoded.count, points.count * 45) // zlib compressed
        let decoded = try TrackBlobCodec.decode(encoded)
        XCTAssertEqual(decoded.count, points.count)
        XCTAssertEqual(decoded[50].isPaused, true)
        XCTAssertEqual(decoded[0].heartRate ?? -1, 155.0, accuracy: 0.1)
        XCTAssertNil(decoded[1].heartRate)
        XCTAssertEqual(decoded[119].latitude, points[119].latitude, accuracy: 1e-6)

        // Journal line codec drops a truncated trailing line gracefully
        var journal = JournalLineCodec.encodeBatch(Array(points.prefix(10)))
        journal.append(contentsOf: "{\"timestamp\":\"2026-01-01".utf8)
        let recovered = JournalLineCodec.decodeLines(journal)
        XCTAssertEqual(recovered.count, 10)
    }

    func testSteadyRunAndRoadRideFixturesSplitsAndSummaries() throws {
        let runPoints = try loadFixture("steady_run")
        XCTAssertEqual(runPoints.count, 160)
        let runSummary = TrackAnalyzer.summarize(points: runPoints, activityType: .run, unitSystem: .metric)
        XCTAssertEqual(runSummary.distanceMeters, 5247, accuracy: 120)
        XCTAssertEqual(runSummary.elevationGainMeters, 55, accuracy: 5)
        XCTAssertEqual(runSummary.splits.count, 6) // 5 full km + 1 partial
        XCTAssertFalse(runSummary.splits[0].isPartial)
        XCTAssertTrue(runSummary.splits[5].isPartial)

        let ridePoints = try loadFixture("road_ride")
        XCTAssertEqual(ridePoints.count, 180)
        let rideSummary = TrackAnalyzer.summarize(points: ridePoints, activityType: .ride, unitSystem: .imperial)
        XCTAssertEqual(rideSummary.distanceMeters, 11920, accuracy: 180)
        XCTAssertEqual(rideSummary.elevationGainMeters, 120, accuracy: 6)
        XCTAssertNotNil(rideSummary.averageHeartRate)
        XCTAssertNotNil(rideSummary.maxHeartRate)
        XCTAssertGreaterThan(rideSummary.splits.count, 6)
    }

    func testNoisyUrbanFixtureFiltersSpikesAndElevationJitter() throws {
        let noisyPoints = try loadFixture("noisy_urban_gps")
        var engine = RecordingSessionEngine(
            activityType: .run,
            unitSystem: .metric,
            startDate: noisyPoints[0].timestamp
        )

        var currentNow = noisyPoints[0].timestamp
        var rejectedCount = 0
        for pt in noisyPoints {
            if pt.timestamp > currentNow {
                currentNow = pt.timestamp
            }
            let result = engine.ingest(pt, now: currentNow)
            if case .reject = result.decision {
                rejectedCount += 1
            }
        }
        let summary = engine.finish(at: currentNow)

        // Expect all 3 injected anomalies (poor accuracy, jump, backward timestamp) rejected
        XCTAssertGreaterThanOrEqual(rejectedCount, 3)
        // Clean path is ~1.475 km without the +555m jump
        XCTAssertLessThan(summary.distanceMeters, 1750)
        XCTAssertGreaterThan(summary.distanceMeters, 1200)
        // Elevation jitter of ±1.2m must not cross 3m hysteresis
        XCTAssertEqual(summary.elevationGainMeters, 0, accuracy: 0.01)
    }

    func testStopAndGoWalkFixtureSeparatesMovingFromElapsedTime() throws {
        let walkPoints = try loadFixture("stop_and_go_walk")
        var engine = RecordingSessionEngine(
            activityType: .walk,
            unitSystem: .metric,
            startDate: walkPoints[0].timestamp,
            autoPauseEnabled: true
        )

        var sawAutoPause = false
        var sawAutoResume = false
        for pt in walkPoints {
            let res = engine.ingest(pt, now: pt.timestamp)
            if res.movingTransition == .didAutoPause { sawAutoPause = true }
            if res.movingTransition == .didAutoResume { sawAutoResume = true }
        }
        let summary = engine.finish(at: walkPoints.last!.timestamp)

        XCTAssertTrue(sawAutoPause)
        XCTAssertTrue(sawAutoResume)
        XCTAssertEqual(summary.elapsedTime, 1440, accuracy: 1.0)
        XCTAssertLessThan(summary.movingTime, summary.elapsedTime - 100.0)
        XCTAssertGreaterThan(summary.distanceMeters, 1700)
    }
}
