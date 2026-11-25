import Foundation

public struct HeatmapTrackInput: Sendable, Equatable {
    public let id: UUID
    public let activityType: ActivityType
    public let coordinates: [PreviewCoordinate]

    public init(id: UUID, activityType: ActivityType, coordinates: [PreviewCoordinate]) {
        self.id = id
        self.activityType = activityType
        self.coordinates = coordinates
    }
}

public struct HeatmapTrack: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let activityType: ActivityType
    public let coordinates: [PreviewCoordinate]

    public init(id: UUID, activityType: ActivityType, coordinates: [PreviewCoordinate]) {
        self.id = id
        self.activityType = activityType
        self.coordinates = coordinates
    }
}

public struct HeatmapBounds: Sendable, Equatable {
    public let centerLatitude: Double
    public let centerLongitude: Double
    public let latitudeDelta: Double
    public let longitudeDelta: Double

    public init(
        centerLatitude: Double,
        centerLongitude: Double,
        latitudeDelta: Double,
        longitudeDelta: Double
    ) {
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }
}

public struct HeatmapSummary: Sendable, Equatable {
    public let tracks: [HeatmapTrack]
    public let totalPoints: Int
    public let bounds: HeatmapBounds?

    public init(tracks: [HeatmapTrack], totalPoints: Int, bounds: HeatmapBounds?) {
        self.tracks = tracks
        self.totalPoints = totalPoints
        self.bounds = bounds
    }
}

public enum HeatmapBuilder {
    public static func build(
        inputs: [HeatmapTrackInput],
        activityTypeFilter: ActivityType? = nil,
        maxPointsPerTrack: Int = 80
    ) -> HeatmapSummary {
        let cap = max(2, maxPointsPerTrack)
        var tracks: [HeatmapTrack] = []
        var totalPoints = 0

        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude

        for input in inputs {
            if let filter = activityTypeFilter, input.activityType != filter {
                continue
            }
            guard input.coordinates.count >= 2 else { continue }

            let sampled = downsample(input.coordinates, maxCount: cap)
            tracks.append(HeatmapTrack(id: input.id, activityType: input.activityType, coordinates: sampled))
            totalPoints += sampled.count

            for coord in sampled {
                if coord.latitude < minLat { minLat = coord.latitude }
                if coord.latitude > maxLat { maxLat = coord.latitude }
                if coord.longitude < minLon { minLon = coord.longitude }
                if coord.longitude > maxLon { maxLon = coord.longitude }
            }
        }

        let bounds: HeatmapBounds?
        if tracks.isEmpty {
            bounds = nil
        } else {
            let latSpan = max(0.01, (maxLat - minLat) * 1.2)
            let lonSpan = max(0.01, (maxLon - minLon) * 1.2)
            bounds = HeatmapBounds(
                centerLatitude: (minLat + maxLat) * 0.5,
                centerLongitude: (minLon + maxLon) * 0.5,
                latitudeDelta: latSpan,
                longitudeDelta: lonSpan
            )
        }

        return HeatmapSummary(tracks: tracks, totalPoints: totalPoints, bounds: bounds)
    }

    private static func downsample(_ coords: [PreviewCoordinate], maxCount: Int) -> [PreviewCoordinate] {
        guard coords.count > maxCount, maxCount >= 2 else { return coords }
        var result: [PreviewCoordinate] = []
        result.reserveCapacity(maxCount)
        let lastIndex = coords.count - 1
        let step = Double(lastIndex) / Double(maxCount - 1)
        for i in 0..<(maxCount - 1) {
            let idx = min(lastIndex, Int((Double(i) * step).rounded()))
            result.append(coords[idx])
        }
        result.append(coords[lastIndex])
        return result
    }
}
