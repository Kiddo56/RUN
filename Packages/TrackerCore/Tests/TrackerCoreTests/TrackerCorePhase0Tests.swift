import XCTest
@testable import TrackerCore

final class TrackerCorePhase0Tests: XCTestCase {
    func testGeoMathIdenticalPointsZeroDistance() {
        let d = GeoMath.distanceMeters(lat1: 37.7749, lon1: -122.4194, lat2: 37.7749, lon2: -122.4194)
        XCTAssertEqual(d, 0.0, accuracy: 1e-9)
    }

    func testGeoMathOneDegreeLatitude() {
        let d = GeoMath.distanceMeters(lat1: 0.0, lon1: 0.0, lat2: 1.0, lon2: 0.0)
        // Spherical earth 6371km * pi/180 ≈ 111,194.9 m
        XCTAssertEqual(d, 111_194.9, accuracy: 200.0)
    }

    func testGeoMathBearings() {
        XCTAssertEqual(GeoMath.bearingDegrees(lat1: 0, lon1: 0, lat2: 1, lon2: 0), 0.0, accuracy: 0.5)
        XCTAssertEqual(GeoMath.bearingDegrees(lat1: 0, lon1: 0, lat2: 0, lon2: 1), 90.0, accuracy: 0.5)
        XCTAssertEqual(GeoMath.bearingDegrees(lat1: 1, lon1: 0, lat2: 0, lon2: 0), 180.0, accuracy: 0.5)
        XCTAssertEqual(GeoMath.bearingDegrees(lat1: 0, lon1: 1, lat2: 0, lon2: 0), 270.0, accuracy: 0.5)
        XCTAssertEqual(GeoMath.angleDifferenceDegrees(350, 10), 20.0, accuracy: 1e-6)
    }

    func testCrossTrackDistance() {
        let d = GeoMath.crossTrackDistanceMeters(
            point: (latitude: 0.001, longitude: 0.005),
            segmentStart: (latitude: 0.0, longitude: 0.0),
            segmentEnd: (latitude: 0.0, longitude: 0.01)
        )
        XCTAssertEqual(d, 111.195, accuracy: 2.0)
    }

    func testRunFormatterMetricAndImperial() {
        XCTAssertEqual(RunFormatter.distance(meters: 5420, unit: .metric), "5.42 km")
        XCTAssertEqual(RunFormatter.distance(meters: 1609.344, unit: .imperial), "1.00 mi")

        // 5:00 /km = 300s / 1000m = 0.3 s/m
        XCTAssertEqual(RunFormatter.pace(secondsPerMeter: 0.3, unit: .metric), "5:00 /km")
        XCTAssertEqual(RunFormatter.pace(secondsPerMeter: 0, unit: .metric), "--:-- /km")

        XCTAssertEqual(RunFormatter.speed(metersPerSecond: 10.0, unit: .metric), "36.0 km/h")
        XCTAssertEqual(RunFormatter.elevation(meters: 100.0, unit: .metric), "100 m")
        XCTAssertEqual(RunFormatter.elevation(meters: 100.0, unit: .imperial), "328 ft")

        XCTAssertEqual(RunFormatter.duration(seconds: 75), "01:15")
        XCTAssertEqual(RunFormatter.duration(seconds: 3665), "1:01:05")
    }

    func testFeatureFlagsDefaultOff() {
        let flags = FeatureFlags()
        XCTAssertFalse(flags.bleHeartRate)
        XCTAssertFalse(flags.barometricAltimeter)
        XCTAssertFalse(flags.personalSections)
        XCTAssertFalse(flags.personalHeatmap)
    }

    func testActivityTypeCodableRoundTrip() throws {
        for type in ActivityType.allCases {
            let encoded = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(ActivityType.self, from: encoded)
            XCTAssertEqual(decoded, type)
        }
        XCTAssertTrue(ActivityType.ride.prefersSpeedOverPace)
        XCTAssertFalse(ActivityType.run.prefersSpeedOverPace)
    }

    func testPlaceholderFixtureExists() {
        let url = Bundle.module.url(forResource: "placeholder", withExtension: "gpx")
        XCTAssertNotNil(url)
    }
}
