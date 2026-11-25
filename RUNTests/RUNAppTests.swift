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

    func testTrimAndMergePersistenceRoundTrip() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("run_edit_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = TrackFileStore(baseDirectory: tempRoot)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        var pointsA: [TrackPoint] = []
        for i in 0..<20 {
            pointsA.append(
                TrackPoint(
                    timestamp: t0.addingTimeInterval(Double(i) * 10),
                    latitude: 37.7700 + Double(i) * 0.0003,
                    longitude: -122.4100,
                    altitude: 20 + Double(i)
                )
            )
        }
        try store.saveTrackPoints(pointsA, fileName: "a.trk")
        let reloadedA = try store.loadTrackPoints(fileName: "a.trk")

        let trimmed = try XCTUnwrap(
            TrackEditor.trim(points: reloadedA, startIndex: 2, endIndex: 17, activityType: .run, unitSystem: .metric)
        )
        XCTAssertEqual(trimmed.points.count, 16)
        try store.saveTrackPoints(trimmed.points, fileName: "a.trk")
        XCTAssertEqual(try store.loadTrackPoints(fileName: "a.trk").count, 16)

        var pointsB: [TrackPoint] = []
        let t1 = t0.addingTimeInterval(1200)
        for i in 0..<10 {
            pointsB.append(
                TrackPoint(
                    timestamp: t1.addingTimeInterval(Double(i) * 10),
                    latitude: 37.7800 + Double(i) * 0.0003,
                    longitude: -122.4100,
                    altitude: 30
                )
            )
        }
        let merged = try XCTUnwrap(
            TrackEditor.merge(first: trimmed.points, second: pointsB, activityType: .run, unitSystem: .metric)
        )
        XCTAssertGreaterThan(merged.summary.distanceMeters, trimmed.summary.distanceMeters)
    }

    func testGearAndGoalSwiftDataPersistenceAndProgress() throws {
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

        let shoe = SDGear(
            name: "Road Trainers",
            categoryRaw: "shoes",
            brand: "TestBrand",
            initialDistanceMeters: 100_000,
            maxDistanceMeters: 800_000,
            isDefaultForRun: true
        )
        context.insert(shoe)

        let now = Date()
        let act = SDActivity(
            activityType: .run,
            startDate: now,
            endDate: now.addingTimeInterval(1500),
            movingTime: 1500,
            elapsedTime: 1500,
            distanceMeters: 5_000,
            elevationGainMeters: 30,
            title: "Morning Run",
            gearID: shoe.id,
            trackFileName: "shoe_run.trk"
        )
        context.insert(act)

        let goal = SDGoal(
            title: "Weekly 20 km",
            periodRaw: "weekly",
            metricRaw: "distanceMeters",
            targetValue: 20_000,
            activityTypeRaw: ActivityType.run.rawValue
        )
        context.insert(goal)
        try context.save()

        let fetchedGear = try context.fetch(FetchDescriptor<SDGear>())
        let fetchedGoals = try context.fetch(FetchDescriptor<SDGoal>())
        XCTAssertEqual(fetchedGear.count, 1)
        XCTAssertEqual(fetchedGoals.count, 1)

        let input = ActivityStatsInput(
            id: act.id,
            title: act.title,
            activityType: act.activityType,
            startDate: act.startDate,
            movingTime: act.movingTime,
            distanceMeters: act.distanceMeters,
            elevationGainMeters: act.elevationGainMeters,
            effortScore: act.effortScore,
            estimatedCalories: act.estimatedCalories,
            gearID: act.gearID
        )
        let progress = StatsAggregator.goalProgress(
            activities: [input],
            periodRaw: goal.periodRaw,
            metricRaw: goal.metricRaw,
            activityTypeFilter: .run,
            referenceDate: now
        )
        XCTAssertEqual(progress, 5_000, accuracy: 0.1)
    }

    func testFullBackupRestoreAndGPXImportRoundTrip() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("run_backup_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = TrackFileStore(baseDirectory: tempRoot)
        let suiteName = "run.backup.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettingsStore(userDefaults: defaults)
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

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let pts = [
            TrackPoint(timestamp: t0, latitude: 37.7700, longitude: -122.4100, altitude: 15),
            TrackPoint(timestamp: t0.addingTimeInterval(30), latitude: 37.7710, longitude: -122.4100, altitude: 20),
            TrackPoint(timestamp: t0.addingTimeInterval(60), latitude: 37.7720, longitude: -122.4100, altitude: 24)
        ]
        let gpxData = GPXCodec.exportActivity(title: "Imported GPX Run", activityType: .run, startDate: t0, points: pts)
        let importedAct = try DataTransferService.importGPXAsActivity(
            data: gpxData,
            fallbackName: "Fallback",
            modelContext: context,
            settings: settings,
            fileStore: store
        )
        XCTAssertEqual(importedAct.title, "Imported GPX Run")
        XCTAssertEqual(importedAct.pointCount, 3)

        let importedRoute = try DataTransferService.importGPXAsRoute(
            data: gpxData,
            fallbackName: "Route Fallback",
            modelContext: context
        )
        XCTAssertEqual(importedRoute.decodedWaypoints().count, 3)

        XCTAssertTrue(settings.needsBackupReminder(activityCount: 1))
        let backupURL = try DataTransferService.exportFullBackup(
            modelContext: context,
            settings: settings,
            appVersion: "1.0.0",
            fileStore: store
        )
        defer { try? FileManager.default.removeItem(at: backupURL) }
        XCTAssertFalse(settings.needsBackupReminder(activityCount: 1))

        let backupBytes = try Data(contentsOf: backupURL)
        let restoreSummary = try DataTransferService.restoreFullBackup(
            data: backupBytes,
            modelContext: context,
            settings: settings,
            replaceExisting: true,
            fileStore: store
        )
        XCTAssertEqual(restoreSummary.activitiesRestored, 1)
        XCTAssertEqual(restoreSummary.routesRestored, 1)

        let restoredActivities = try context.fetch(FetchDescriptor<SDActivity>())
        XCTAssertEqual(restoredActivities.count, 1)
        XCTAssertEqual(try store.loadTrackPoints(fileName: restoredActivities[0].trackFileName).count, 3)
    }

    func testPhase5SectionPersistenceAndSensorDefaults() throws {
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

        let bearing = GeoMath.bearingDegrees(
            lat1: 37.7700,
            lon1: -122.4100,
            lat2: 37.7745,
            lon2: -122.4100
        )
        let dist = GeoMath.distanceMeters(
            lat1: 37.7700,
            lon1: -122.4100,
            lat2: 37.7745,
            lon2: -122.4100
        )
        let section = SDSection(
            name: "Park Climb",
            activityTypeRaw: ActivityType.run.rawValue,
            startLatitude: 37.7700,
            startLongitude: -122.4100,
            endLatitude: 37.7745,
            endLongitude: -122.4100,
            expectedBearing: bearing,
            distanceMeters: dist,
            corridorMeters: 35.0
        )
        context.insert(section)
        try context.save()

        let fetchedSections = try context.fetch(FetchDescriptor<SDSection>())
        XCTAssertEqual(fetchedSections.count, 1)
        XCTAssertEqual(fetchedSections[0].name, "Park Climb")

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        var track: [TrackPoint] = []
        for i in 0...30 {
            let frac = Double(i) / 30.0
            track.append(
                TrackPoint(
                    timestamp: t0.addingTimeInterval(Double(i) * 5.0),
                    latitude: 37.7700 + frac * 0.0045,
                    longitude: -122.4100,
                    altitude: 15.0 + frac * 10.0
                )
            )
        }
        let spec = SectionSpec(
            id: section.id,
            name: section.name,
            activityType: .run,
            startLatitude: section.startLatitude,
            startLongitude: section.startLongitude,
            endLatitude: section.endLatitude,
            endLongitude: section.endLongitude,
            expectedBearing: section.expectedBearing,
            distanceMeters: section.distanceMeters,
            corridorMeters: section.corridorMeters
        )
        let attempts = SectionMatcher.findAttempts(
            section: spec,
            activityID: UUID(),
            activityTitle: "Evening Run",
            activityType: .run,
            points: track
        )
        XCTAssertEqual(attempts.count, 1)

        // Ensure Phase 5 hardware services start strictly idle when feature flags are OFF.
        let hrMonitor = HeartRateMonitorService()
        XCTAssertEqual(hrMonitor.connectionState, .idle)
        XCTAssertNil(hrMonitor.currentBPM)

        let barometer = BarometerService()
        XCTAssertFalse(barometer.isRunning)
        XCTAssertNil(barometer.fusedAltitudeMeters)
    }
}
