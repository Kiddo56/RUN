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
        XCTAssertFalse(store.featureFlags.bleHeartRate)
        XCTAssertFalse(store.featureFlags.barometricAltimeter)
        XCTAssertFalse(store.featureFlags.personalSections)
        XCTAssertFalse(store.featureFlags.personalHeatmap)

        store.unitSystem = .imperial
        store.featureFlags.personalHeatmap = true

        let reloaded = AppSettingsStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.unitSystem, .imperial)
        XCTAssertTrue(reloaded.featureFlags.personalHeatmap)
    }

    func testTrackerCoreIntegration() {
        let d = GeoMath.distanceMeters(lat1: 37.7749, lon1: -122.4194, lat2: 37.7849, lon2: -122.4194)
        XCTAssertEqual(d, 1111.9, accuracy: 5.0)
        XCTAssertEqual(RunFormatter.distance(meters: d, unit: .metric), "1.11 km")
    }
}
