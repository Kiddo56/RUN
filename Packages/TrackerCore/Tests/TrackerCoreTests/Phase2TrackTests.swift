import XCTest
@testable import TrackerCore

final class Phase2TrackTests: XCTestCase {
    private func loadFixture(_ name: String) throws -> [TrackPoint] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "gpx"))
        let data = try Data(contentsOf: url)
        return try BasicGPXReader.parseTrackPoints(from: data)
    }

    func testTrackChartBuilderSamplesAndNearestLookup() throws {
        let ridePoints = try loadFixture("road_ride")
        let samples = TrackChartBuilder.buildSamples(points: ridePoints, unitSystem: .metric, maxSamples: 80)

        XCTAssertLessThanOrEqual(samples.count, 80)
        XCTAssertGreaterThan(samples.count, 40)
        XCTAssertEqual(samples.first?.distanceMeters ?? -1, 0, accuracy: 0.01)
        XCTAssertGreaterThan(samples.last?.distanceMeters ?? 0, 11_000)

        // Monotonic distance & HR preserved
        for i in 1..<samples.count {
            XCTAssertGreaterThanOrEqual(samples[i].distanceMeters, samples[i - 1].distanceMeters)
        }
        XCTAssertNotNil(samples.first?.heartRate)

        let target = 5_000.0
        let nearest = try XCTUnwrap(TrackChartBuilder.nearestSample(in: samples, toDistanceMeters: target))
        XCTAssertEqual(nearest.distanceMeters, target, accuracy: 350.0)
    }

    func testColoredTrackSegmentsAreContinuousAndNormalized() throws {
        let runPoints = try loadFixture("steady_run")
        let segments = TrackChartBuilder.buildColoredSegments(points: runPoints, maxSegments: 40)

        XCTAssertEqual(segments.count, 40)
        for idx in 0..<segments.count {
            XCTAssertGreaterThanOrEqual(segments[idx].intensityNormalized, 0.0)
            XCTAssertLessThanOrEqual(segments[idx].intensityNormalized, 1.0)
            if idx + 1 < segments.count {
                XCTAssertEqual(segments[idx].coordinates.last, segments[idx + 1].coordinates.first)
            }
        }
    }

    func testTrackEditorTrimReducesTrackAndRejectsInvalidBounds() throws {
        let runPoints = try loadFixture("steady_run")
        let originalSummary = TrackAnalyzer.summarize(points: runPoints, activityType: .run)

        XCTAssertNil(TrackEditor.trim(points: runPoints, startIndex: 10, endIndex: 10, activityType: .run, unitSystem: .metric))
        XCTAssertNil(TrackEditor.trim(points: runPoints, startIndex: -1, endIndex: 20, activityType: .run, unitSystem: .metric))

        let trimmed = try XCTUnwrap(
            TrackEditor.trim(
                points: runPoints,
                startIndex: 20,
                endIndex: runPoints.count - 21,
                activityType: .run,
                unitSystem: .metric
            )
        )
        XCTAssertEqual(trimmed.points.count, runPoints.count - 40)
        XCTAssertLessThan(trimmed.summary.distanceMeters, originalSummary.distanceMeters - 1000)
        XCTAssertLessThan(trimmed.summary.movingTime, originalSummary.movingTime - 300)
    }

    func testTrackEditorMergeDoesNotInflateDistanceAcrossGap() throws {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        var trackA: [TrackPoint] = []
        for i in 0..<15 {
            trackA.append(
                TrackPoint(
                    timestamp: t0.addingTimeInterval(Double(i) * 10),
                    latitude: 37.7700 + Double(i) * 0.0003,
                    longitude: -122.4100,
                    altitude: 20
                )
            )
        }

        // Track B starts 10 minutes later, 2 km away
        let t1 = t0.addingTimeInterval(600)
        var trackB: [TrackPoint] = []
        for i in 0..<15 {
            trackB.append(
                TrackPoint(
                    timestamp: t1.addingTimeInterval(Double(i) * 10),
                    latitude: 37.7900 + Double(i) * 0.0003,
                    longitude: -122.4100,
                    altitude: 25
                )
            )
        }

        let sumA = TrackAnalyzer.summarize(points: trackA, activityType: .run).distanceMeters
        let sumB = TrackAnalyzer.summarize(points: trackB, activityType: .run).distanceMeters

        // Pass in reverse chronological order to verify automatic chronological sorting
        let merged = try XCTUnwrap(
            TrackEditor.merge(first: trackB, second: trackA, activityType: .run, unitSystem: .metric)
        )
        XCTAssertEqual(merged.summary.distanceMeters, sumA + sumB, accuracy: 5.0)
        XCTAssertEqual(merged.summary.elapsedTime, 740.0, accuracy: 2.0)
    }
}
