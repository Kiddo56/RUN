import XCTest
@testable import TrackerCore

final class Phase4IOAndRoutesTests: XCTestCase {
    private func loadFixture(_ name: String) throws -> [TrackPoint] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "gpx"))
        let data = try Data(contentsOf: url)
        return try BasicGPXReader.parseTrackPoints(from: data)
    }

    func testGPXCodecExportAndParseRoundTrip() throws {
        let ridePoints = try loadFixture("road_ride")
        var pointsWithPause = ridePoints
        pointsWithPause[50].isPaused = true

        let xmlData = GPXCodec.exportActivity(
            title: "Morning & Hills <Test>",
            activityType: .ride,
            startDate: ridePoints[0].timestamp,
            points: pointsWithPause
        )
        let parsed = try GPXCodec.parse(data: xmlData)
        XCTAssertEqual(parsed.name, "Morning & Hills <Test>")
        XCTAssertEqual(parsed.activityType, .ride)
        XCTAssertEqual(parsed.points.count, ridePoints.count - 1)
        XCTAssertNotNil(parsed.points.first?.heartRate)
        XCTAssertFalse(parsed.routeWaypoints.isEmpty)

        // Route export & parse round-trip
        let waypoints = [
            RouteWaypoint(latitude: 37.7700, longitude: -122.4100, altitude: 10, name: "Start"),
            RouteWaypoint(latitude: 37.7800, longitude: -122.4100, altitude: 25, name: "Turn"),
            RouteWaypoint(latitude: 37.7800, longitude: -122.4000, altitude: 15, name: "Finish")
        ]
        let routeGPX = GPXCodec.exportRoute(name: "Loop & Climb", waypoints: waypoints)
        let parsedRoute = try GPXCodec.parse(data: routeGPX)
        XCTAssertEqual(parsedRoute.name, "Loop & Climb")
        XCTAssertEqual(parsedRoute.routeWaypoints.count, 3)
        XCTAssertEqual(parsedRoute.routeWaypoints[1].name, "Turn")
    }

    func testPureZipWriterCRC32AndArchive() {
        // Standard IEEE 802.3 CRC32 vector for "123456789"
        XCTAssertEqual(PureZipWriter.crc32(Data("123456789".utf8)), 0xCBF4_3926)

        let zipData = PureZipWriter.createArchive(entries: [
            ZipEntry(fileName: "run1.gpx", data: Data("<gpx>one</gpx>".utf8)),
            ZipEntry(fileName: "run2.gpx", data: Data("<gpx>two</gpx>".utf8))
        ])
        // Starts with PKZIP local file header signature 0x50 0x4B 0x03 0x04
        XCTAssertEqual(Array(zipData.prefix(4)), [0x50, 0x4B, 0x03, 0x04])
        XCTAssertTrue(zipData.count > 120)
    }

    func testCSVExporterRFC4180Escaping() throws {
        let row = CSVActivityRow(
            id: UUID(),
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            title: "Run, \"Hills\" & Park",
            activityType: .run,
            distanceMeters: 5000,
            movingTime: 1500,
            elapsedTime: 1550,
            elevationGainMeters: 42,
            elevationLossMeters: 40,
            averageHeartRate: 155,
            maxHeartRate: 175,
            effortScore: 48,
            estimatedCalories: 350,
            gearName: "Daily Shoes",
            source: "recorded",
            notes: "Line 1\nLine 2"
        )
        let csvData = CSVExporter.export(rows: [row], unitSystem: .metric)
        let text = try XCTUnwrap(String(data: csvData, encoding: .utf8))
        XCTAssertTrue(text.contains("\"Run, \"\"Hills\"\" & Park\""))
        XCTAssertTrue(text.contains("\"Line 1\nLine 2\""))
    }

    func testBackupCodecVersionedRoundTripAndVersionGuard() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let points = [
            TrackPoint(timestamp: now, latitude: 37.77, longitude: -122.41, altitude: 12),
            TrackPoint(timestamp: now.addingTimeInterval(10), latitude: 37.771, longitude: -122.41, altitude: 15)
        ]
        let blob = try TrackBlobCodec.encode(points)

        let envelope = BackupEnvelope(
            schemaVersion: BackupEnvelope.currentSchemaVersion,
            exportedAt: now,
            appVersion: "1.0.0",
            settings: BackupSettings(
                unitSystem: .metric,
                featureFlags: FeatureFlags(),
                autoPauseEnabled: true,
                audioCuesEnabled: true,
                hapticsEnabled: true,
                maxHorizontalAccuracyMeters: 30,
                elevationHysteresisMeters: 3,
                userWeightKg: 70,
                privacyHideRadiusMeters: 200
            ),
            activities: [
                BackupActivityRecord(
                    id: UUID(),
                    activityType: .run,
                    startDate: now,
                    endDate: now.addingTimeInterval(10),
                    movingTime: 10,
                    elapsedTime: 10,
                    distanceMeters: 111,
                    elevationGainMeters: 3,
                    elevationLossMeters: 0,
                    averageHeartRate: nil,
                    maxHeartRate: nil,
                    effortScore: 5,
                    estimatedCalories: 10,
                    title: "Backup Run",
                    notes: "",
                    gearID: nil,
                    source: "recorded",
                    trackFileName: "test.trk",
                    trackBlobData: blob,
                    splits: [],
                    previewCoordinates: [],
                    pointCount: 2
                )
            ],
            gear: [],
            goals: [],
            routes: [
                BackupRouteRecord(
                    id: UUID(),
                    name: "Test Route",
                    notes: "",
                    createdAt: now,
                    distanceMeters: 1000,
                    elevationGainMeters: 10,
                    source: "drawn",
                    waypoints: [RouteWaypoint(latitude: 37.77, longitude: -122.41)]
                )
            ],
            sections: []
        )

        let encoded = try BackupCodec.encode(envelope)
        let decoded = try BackupCodec.decode(encoded)
        XCTAssertEqual(decoded.activities.count, 1)
        XCTAssertEqual(try TrackBlobCodec.decode(decoded.activities[0].trackBlobData).count, 2)
        XCTAssertEqual(decoded.routes.first?.name, "Test Route")

        let invalid = BackupEnvelope(
            schemaVersion: 99,
            exportedAt: now,
            appVersion: "9.9.9",
            settings: envelope.settings,
            activities: [],
            gear: [],
            goals: [],
            routes: [],
            sections: []
        )
        let invalidData = try BackupCodec.encode(invalid)
        XCTAssertThrowsError(try BackupCodec.decode(invalidData))
    }

    func testRouteNavigationEngineOnAndOffRoute() {
        let waypoints = [
            RouteWaypoint(latitude: 0.0, longitude: 0.0),
            RouteWaypoint(latitude: 0.0, longitude: 0.01) // ~1.11 km east
        ]
        let total = RouteNavigationEngine.totalDistanceMeters(waypoints: waypoints)
        XCTAssertEqual(total, 1111.9, accuracy: 5.0)

        let onRoute = RouteNavigationEngine.evaluate(
            latitude: 0.00005,
            longitude: 0.005,
            waypoints: waypoints,
            offRouteThresholdMeters: 50.0
        )
        XCTAssertFalse(onRoute.isOffRoute)
        XCTAssertLessThan(onRoute.distanceOffRouteMeters, 15.0)
        XCTAssertEqual(onRoute.remainingDistanceMeters, 556.0, accuracy: 20.0)

        let offRoute = RouteNavigationEngine.evaluate(
            latitude: 0.0012, // ~133 m north
            longitude: 0.005,
            waypoints: waypoints,
            offRouteThresholdMeters: 50.0
        )
        XCTAssertTrue(offRoute.isOffRoute)
        XCTAssertGreaterThan(offRoute.distanceOffRouteMeters, 120.0)
    }
}
