import SwiftData
import XCTest
import TrackerCore
@testable import RUN

@MainActor
final class RUNAppTests: XCTestCase {
    func testAppBuildInfoCurrentHasBundleID() {
        let info = AppBuildInfo.current()
        XCTAssertFalse(info.version.isEmpty)
        XCTAssertFalse(info.buildNumber.isEmpty)
        XCTAssertFalse(info.commitSHA.isEmpty)
        XCTAssertFalse(info.bundleIdentifier.isEmpty)
    }

    func testDiagnosticsLoggerAppendCapAndExport() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_diag_\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let logger = DiagnosticsLogger(storageURL: tempFile, maxEntries: 3)
        logger.log(.lifecycle, "one")
        logger.log(.auth, "two")
        logger.log(.location, "three")
        logger.log(.error, "four")

        XCTAssertEqual(logger.entries.count, 3)
        XCTAssertEqual(logger.entries.map(\.message), ["two", "three", "four"])

        let exported = logger.exportText()
        XCTAssertTrue(exported.contains("RUN Diagnostics Export"))
        XCTAssertTrue(exported.contains("[ERROR] four"))

        let fileURL = try XCTUnwrap(logger.exportFileURL())
        let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(fileContents.contains("[AUTH] two"))

        logger.clear()
        XCTAssertTrue(logger.entries.isEmpty)
    }

    func testAppSettingsStoreDefaultsAndPersistence() {
        let suiteName = "run.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        XCTAssertEqual(store.unitSystem, .metric)
        XCTAssertTrue(store.autoPauseEnabled)
        XCTAssertTrue(store.audioCuesEnabled)
        XCTAssertTrue(store.hapticsEnabled)
        XCTAssertEqual(store.maxHorizontalAccuracyMeters, 30.0, accuracy: 0.01)
        XCTAssertFalse(store.featureFlags.bleHeartRate)
        XCTAssertFalse(store.featureFlags.barometricAltimeter)
        XCTAssertFalse(store.featureFlags.personalSections)
        XCTAssertFalse(store.featureFlags.personalHeatmap)

        store.unitSystem = .imperial
        store.autoPauseEnabled = false
        store.featureFlags.personalHeatmap = true

        let reloaded = AppSettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.unitSystem, .imperial)
        XCTAssertFalse(reloaded.autoPauseEnabled)
        XCTAssertTrue(reloaded.featureFlags.personalHeatmap)
    }

    func testTrackFileStoreBlobAndRecoveryJournalRoundTrip() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("run_store_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = TrackFileStore(baseDirectory: tempRoot)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let points = [
            TrackPoint(timestamp: now, latitude: 37.77, longitude: -122.41, altitude: 10),
            TrackPoint(timestamp: now.addingTimeInterval(10), latitude: 37.771, longitude: -122.41, altitude: 14)
        ]

        let meta = RecoveryMetadata(
            sessionID: UUID(),
            activityType: .run,
            startDate: now,
            lastFlushDate: now.addingTimeInterval(10),
            elapsedTime: 10,
            movingTime: 10,
            distanceMeters: 111.2,
            elevationGainMeters: 4,
            elevationLossMeters: 0
        )

        try store.startJournal(metadata: meta)
        try store.appendJournalPoints(points, metadata: meta)

        let pending = try XCTUnwrap(store.loadPendingRecovery())
        XCTAssertEqual(pending.metadata.sessionID, meta.sessionID)
        XCTAssertEqual(pending.points.count, 2)

        try store.saveTrackPoints(points, fileName: "\(meta.sessionID.uuidString).trk")
        let loaded = try store.loadTrackPoints(fileName: "\(meta.sessionID.uuidString).trk")
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[1].latitude, 37.771, accuracy: 1e-6)

        store.clearJournal()
        XCTAssertNil(store.loadPendingRecovery())
    }

    func testSwiftDataContainerInMemoryActivityInsert() throws {
        let schema = Schema([
            SDActivity.self,
            SDGear.self,
            SDGoal.self,
            SDSavedRoute.self,
            SDSection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let now = Date()
        let act = SDActivity(
            activityType: .run,
            startDate: now,
            endDate: now.addingTimeInterval(600),
            movingTime: 600,
            elapsedTime: 600,
            distanceMeters: 2000,
            elevationGainMeters: 25,
            title: "Test Run",
            trackFileName: "test.trk",
            splits: [
                ActivitySplit(index: 1, distanceMeters: 1000, durationSeconds: 300, movingSeconds: 300, elevationGainMeters: 10, elevationLossMeters: 0),
                ActivitySplit(index: 2, distanceMeters: 1000, durationSeconds: 300, movingSeconds: 300, elevationGainMeters: 15, elevationLossMeters: 0)
            ],
            previewCoordinates: [
                PreviewCoordinate(latitude: 37.77, longitude: -122.41),
                PreviewCoordinate(latitude: 37.78, longitude: -122.41)
            ],
            pointCount: 20
        )
        context.insert(act)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SDActivity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].decodedSplits().count, 2)
        XCTAssertEqual(fetched[0].decodedPreviewCoordinates().count, 2)
    }
}
