import Foundation
import XCTest
@testable import TrackerCore

final class Phase5ExtrasTests: XCTestCase {
    func testBLEHeartRateParser8Bit16BitAndInvalid() {
        let hr8 = Data([0x00, 148])
        XCTAssertEqual(BLEHeartRateParser.parseBPM(from: hr8), 148.0)

        let hr16 = Data([0x01, 0x04, 0x01, 0x00])
        XCTAssertEqual(BLEHeartRateParser.parseBPM(from: hr16), 260.0)

        // Sub-slice with non-zero startIndex
        let wrapped = Data([0xAA, 0x00, 162])
        let slice = wrapped.dropFirst()
        XCTAssertEqual(BLEHeartRateParser.parseBPM(from: slice), 162.0)

        // Invalid / empty / truncated / zero BPM payloads
        XCTAssertNil(BLEHeartRateParser.parseBPM(from: Data()))
        XCTAssertNil(BLEHeartRateParser.parseBPM(from: Data([0x00])))
        XCTAssertNil(BLEHeartRateParser.parseBPM(from: Data([0x01, 0x70])))
        XCTAssertNil(BLEHeartRateParser.parseBPM(from: Data([0x00, 0x00])))
    }

    func testSectionMatcherMatchesForwardAndRejectsReverseAndOffCorridor() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        var forwardPoints: [TrackPoint] = []
        for i in 0..<40 {
            forwardPoints.append(
                TrackPoint(
                    timestamp: baseDate.addingTimeInterval(Double(i) * 4.0),
                    latitude: 37.7700 + Double(i) * 0.00018, // ~20 m per step north
                    longitude: -122.4100,
                    altitude: 10.0
                )
            )
        }

        let startPt = forwardPoints[5]
        let endPt = forwardPoints[35]
        let directDistance = GeoMath.distanceMeters(from: startPt, to: endPt)
        let bearing = GeoMath.bearingDegrees(
            lat1: startPt.latitude,
            lon1: startPt.longitude,
            lat2: endPt.latitude,
            lon2: endPt.longitude
        )

        let section = SectionSpec(
            id: UUID(),
            name: "Waterfront Straight",
            activityType: .run,
            startLatitude: startPt.latitude,
            startLongitude: startPt.longitude,
            endLatitude: endPt.latitude,
            endLongitude: endPt.longitude,
            expectedBearing: bearing,
            distanceMeters: directDistance,
            corridorMeters: 35.0
        )

        let actID1 = UUID()
        let matches = SectionMatcher.findAttempts(
            section: section,
            activityID: actID1,
            activityTitle: "Morning Tempo",
            activityType: .run,
            points: forwardPoints
        )
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].durationSeconds, 120.0, accuracy: 8.0)
        XCTAssertEqual(matches[0].distanceMeters, directDistance, accuracy: 40.0)

        // Reverse track should not match due to bearing guard
        var reversePoints: [TrackPoint] = []
        for i in 0..<40 {
            let source = forwardPoints[39 - i]
            reversePoints.append(
                TrackPoint(
                    timestamp: baseDate.addingTimeInterval(Double(i) * 4.0),
                    latitude: source.latitude,
                    longitude: source.longitude,
                    altitude: source.altitude
                )
            )
        }
        let reverseMatches = SectionMatcher.findAttempts(
            section: section,
            activityID: UUID(),
            activityTitle: "Reverse Jog",
            activityType: .run,
            points: reversePoints
        )
        XCTAssertTrue(reverseMatches.isEmpty)

        // Parallel track shifted ~150m east should not match corridor
        var shiftedPoints: [TrackPoint] = []
        for i in 0..<40 {
            shiftedPoints.append(
                TrackPoint(
                    timestamp: baseDate.addingTimeInterval(Double(i) * 4.0),
                    latitude: forwardPoints[i].latitude,
                    longitude: forwardPoints[i].longitude + 0.0018,
                    altitude: 10.0
                )
            )
        }
        let shiftedMatches = SectionMatcher.findAttempts(
            section: section,
            activityID: UUID(),
            activityTitle: "Parallel Street",
            activityType: .run,
            points: shiftedPoints
        )
        XCTAssertTrue(shiftedMatches.isEmpty)

        // Faster run ranks ahead of slower run
        let fasterAttempt = SectionAttempt(
            id: UUID(),
            sectionID: section.id,
            activityID: UUID(),
            activityTitle: "Fast Track",
            date: baseDate.addingTimeInterval(86_400),
            durationSeconds: 95.0,
            distanceMeters: directDistance,
            paceSecondsPerMeter: 95.0 / directDistance,
            speedMPS: directDistance / 95.0
        )
        let ranked = SectionMatcher.rankAttempts([matches[0], fasterAttempt])
        XCTAssertEqual(ranked.first?.activityTitle, "Fast Track")
    }

    func testHeatmapBuilderFiltersDownsamplesAndComputesBounds() {
        var denseRun: [PreviewCoordinate] = []
        for i in 0..<200 {
            denseRun.append(
                PreviewCoordinate(
                    latitude: 37.7600 + Double(i) * 0.0001,
                    longitude: -122.4200 + Double(i) * 0.00005
                )
            )
        }
        let rideCoords = [
            PreviewCoordinate(latitude: 37.9000, longitude: -122.5000),
            PreviewCoordinate(latitude: 37.9100, longitude: -122.5100)
        ]

        let inputs = [
            HeatmapTrackInput(id: UUID(), activityType: .run, coordinates: denseRun),
            HeatmapTrackInput(id: UUID(), activityType: .ride, coordinates: rideCoords),
            HeatmapTrackInput(id: UUID(), activityType: .run, coordinates: [PreviewCoordinate(latitude: 0, longitude: 0)])
        ]

        let runOnly = HeatmapBuilder.build(inputs: inputs, activityTypeFilter: .run, maxPointsPerTrack: 40)
        XCTAssertEqual(runOnly.tracks.count, 1)
        XCTAssertEqual(runOnly.tracks[0].coordinates.count, 40)
        XCTAssertEqual(runOnly.tracks[0].coordinates.first, denseRun.first)
        XCTAssertEqual(runOnly.tracks[0].coordinates.last, denseRun.last)
        XCTAssertNotNil(runOnly.bounds)
        if let bounds = runOnly.bounds {
            XCTAssertGreaterThanOrEqual(bounds.latitudeDelta, 0.01)
            XCTAssertGreaterThanOrEqual(bounds.longitudeDelta, 0.01)
            XCTAssertEqual(bounds.centerLatitude, (37.7600 + 37.7799) * 0.5, accuracy: 0.001)
        }
    }
}
