import Foundation

public struct TrackChartSample: Identifiable, Sendable, Equatable {
    public let id: Int
    public let pointIndex: Int
    public let distanceMeters: Double
    public let elapsedSeconds: TimeInterval
    public let altitudeMeters: Double
    public let speedMPS: Double
    public let paceMinutesPerUnit: Double
    public let speedInDisplayUnit: Double
    public let heartRate: Double?
    public let latitude: Double
    public let longitude: Double

    public func distanceInDisplayUnit(_ unit: UnitSystem) -> Double {
        distanceMeters / unit.metersPerMajorUnit
    }
}

public struct ColoredTrackSegment: Identifiable, Sendable, Equatable {
    public let id: Int
    public let coordinates: [PreviewCoordinate]
    public let intensityNormalized: Double

    public init(id: Int, coordinates: [PreviewCoordinate], intensityNormalized: Double) {
        self.id = id
        self.coordinates = coordinates
        self.intensityNormalized = intensityNormalized
    }
}

public enum TrackChartBuilder {
    public static func buildSamples(
        points: [TrackPoint],
        unitSystem: UnitSystem,
        maxSamples: Int = 220
    ) -> [TrackChartSample] {
        guard !points.isEmpty else { return [] }

        var cumulativeDistances: [Double] = [0.0]
        cumulativeDistances.reserveCapacity(points.count)
        for idx in 1..<points.count {
            let p0 = points[idx - 1]
            let p1 = points[idx]
            let stepDist = (p0.isPaused && p1.isPaused) ? 0.0 : GeoMath.distanceMeters(from: p0, to: p1)
            cumulativeDistances.append(cumulativeDistances[idx - 1] + stepDist)
        }

        let startDate = points[0].timestamp
        let limit = max(2, maxSamples)
        let indices: [Int]
        if points.count <= limit {
            indices = Array(0..<points.count)
        } else {
            var sampled: [Int] = []
            sampled.reserveCapacity(limit)
            let step = Double(points.count - 1) / Double(limit - 1)
            for k in 0..<limit {
                let idx = min(points.count - 1, Int((Double(k) * step).rounded()))
                if sampled.last != idx {
                    sampled.append(idx)
                }
            }
            if sampled.last != points.count - 1 {
                sampled.append(points.count - 1)
            }
            indices = sampled
        }

        var samples: [TrackChartSample] = []
        samples.reserveCapacity(indices.count)

        for (sampleID, i) in indices.enumerated() {
            let lo = max(0, i - 2)
            let hi = min(points.count - 1, i + 2)
            let dd = max(0.0, cumulativeDistances[hi] - cumulativeDistances[lo])
            let dt = points[hi].timestamp.timeIntervalSince(points[lo].timestamp)
            let localSpeed: Double
            if points[i].isPaused {
                localSpeed = 0.0
            } else if dt > 0.2 {
                localSpeed = dd / dt
            } else {
                localSpeed = max(0.0, points[i].speed)
            }

            let speedDisplay: Double
            switch unitSystem {
            case .metric:
                speedDisplay = localSpeed * 3.6
            case .imperial:
                speedDisplay = localSpeed * 2.2369362920544
            }

            let paceMin: Double
            if localSpeed > 0.25 {
                let rawMinutes = (unitSystem.metersPerMajorUnit / localSpeed) / 60.0
                paceMin = min(25.0, max(0.0, rawMinutes))
            } else {
                paceMin = 0.0
            }

            samples.append(
                TrackChartSample(
                    id: sampleID,
                    pointIndex: i,
                    distanceMeters: cumulativeDistances[i],
                    elapsedSeconds: max(0.0, points[i].timestamp.timeIntervalSince(startDate)),
                    altitudeMeters: points[i].altitude,
                    speedMPS: localSpeed,
                    paceMinutesPerUnit: paceMin,
                    speedInDisplayUnit: speedDisplay,
                    heartRate: points[i].heartRate,
                    latitude: points[i].latitude,
                    longitude: points[i].longitude
                )
            )
        }

        return samples
    }

    public static func buildColoredSegments(
        points: [TrackPoint],
        maxSegments: Int = 60
    ) -> [ColoredTrackSegment] {
        guard points.count >= 2 else { return [] }

        let segmentCount = min(max(1, maxSegments), points.count - 1)
        var rawChunks: [(coords: [PreviewCoordinate], speed: Double)] = []
        rawChunks.reserveCapacity(segmentCount)

        for s in 0..<segmentCount {
            let startIdx = (s * (points.count - 1)) / segmentCount
            let endIdx = max(startIdx + 1, ((s + 1) * (points.count - 1)) / segmentCount)
            let slice = points[startIdx...min(points.count - 1, endIdx)]

            var chunkDist = 0.0
            var chunkDur = 0.0
            var coords: [PreviewCoordinate] = []
            coords.reserveCapacity(slice.count)

            let sliceArray = Array(slice)
            for idx in 0..<sliceArray.count {
                let pt = sliceArray[idx]
                coords.append(PreviewCoordinate(latitude: pt.latitude, longitude: pt.longitude))
                if idx > 0 {
                    let prev = sliceArray[idx - 1]
                    chunkDist += GeoMath.distanceMeters(from: prev, to: pt)
                    chunkDur += max(0.0, pt.timestamp.timeIntervalSince(prev.timestamp))
                }
            }

            let speed = chunkDur > 0.1 ? (chunkDist / chunkDur) : 0.0
            rawChunks.append((coords: coords, speed: speed))
        }

        let sortedSpeeds = rawChunks.map(\.speed).sorted()
        let p10Index = min(sortedSpeeds.count - 1, max(0, Int(Double(sortedSpeeds.count - 1) * 0.10)))
        let p90Index = min(sortedSpeeds.count - 1, max(0, Int(Double(sortedSpeeds.count - 1) * 0.90)))
        let lowSpeed = sortedSpeeds[p10Index]
        let highSpeed = sortedSpeeds[p90Index]
        let span = highSpeed - lowSpeed

        return rawChunks.enumerated().map { idx, chunk in
            let norm: Double
            if span > 0.15 {
                norm = min(1.0, max(0.0, (chunk.speed - lowSpeed) / span))
            } else {
                norm = 0.5
            }
            return ColoredTrackSegment(
                id: idx,
                coordinates: chunk.coords,
                intensityNormalized: norm
            )
        }
    }

    public static func nearestSample(
        in samples: [TrackChartSample],
        toDistanceMeters targetMeters: Double
    ) -> TrackChartSample? {
        guard !samples.isEmpty else { return nil }
        var best = samples[0]
        var bestDiff = abs(best.distanceMeters - targetMeters)
        for sample in samples.dropFirst() {
            let diff = abs(sample.distanceMeters - targetMeters)
            if diff < bestDiff {
                best = sample
                bestDiff = diff
            }
        }
        return best
    }
}
