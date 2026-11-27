import Foundation
import XCTest
@testable import TrackerCore

final class MapHelperTests: XCTestCase {
    func testDownsamplePreservesEndpointsAndRespectsMaxPoints() {
        var coords: [PreviewCoordinate] = []
        for i in 0..<1200 {
            coords.append(
                PreviewCoordinate(
                    latitude: 37.7700 + Double(i) * 0.00005,
                    longitude: -122.4100
                )
            )
        }

        let downsampled = TrackMapHelper.downsample(coords, maxPoints: 300)
        XCTAssertEqual(downsampled.count, 300)
        XCTAssertEqual(downsampled.first, coords.first)
        XCTAssertEqual(downsampled.last, coords.last)
    }

    func testDistanceMarkersMetricAndImperial() {
        // ~3.3 km straight north (~111.1 km per degree lat -> 0.03 deg ~= 3.33 km)
        var coords: [PreviewCoordinate] = []
        for i in 0...60 {
            coords.append(
                PreviewCoordinate(
                    latitude: 37.7000 + Double(i) * 0.0005,
                    longitude: -122.4100
                )
            )
        }

        let kmMarkers = TrackMapHelper.distanceMarkers(coordinates: coords, unitSystem: .metric)
        XCTAssertEqual(kmMarkers.count, 3)
        XCTAssertEqual(kmMarkers[0].label, "1 km")
        XCTAssertEqual(kmMarkers[2].label, "3 km")

        let miMarkers = TrackMapHelper.distanceMarkers(coordinates: coords, unitSystem: .imperial)
        XCTAssertEqual(miMarkers.count, 2)
        XCTAssertEqual(miMarkers[0].label, "1 mi")
        XCTAssertEqual(miMarkers[1].label, "2 mi")
    }

    func testBoundingRegionAndCameraThrottle() {
        let coords = [
            PreviewCoordinate(latitude: 37.70, longitude: -122.45),
            PreviewCoordinate(latitude: 37.72, longitude: -122.41)
        ]
        let region = TrackMapHelper.boundingRegion(for: coords)
        XCTAssertNotNil(region)
        XCTAssertEqual(region?.centerLatitude ?? 0, 37.71, accuracy: 0.001)
        XCTAssertEqual(region?.centerLongitude ?? 0, -122.43, accuracy: 0.001)

        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertFalse(TrackMapHelper.shouldThrottleCameraUpdate(lastUpdate: nil, now: t0))
        XCTAssertTrue(TrackMapHelper.shouldThrottleCameraUpdate(lastUpdate: t0, now: t0.addingTimeInterval(0.5)))
        XCTAssertFalse(TrackMapHelper.shouldThrottleCameraUpdate(lastUpdate: t0, now: t0.addingTimeInterval(2.0)))
    }
}
