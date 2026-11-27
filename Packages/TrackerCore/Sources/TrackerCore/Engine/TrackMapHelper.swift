import Foundation

public struct RouteDistanceMarker: Identifiable, Sendable, Equatable {
    public let unitIndex: Int
    public let latitude: Double
    public let longitude: Double
    public let label: String

    public var id: Int { unitIndex }

    public init(unitIndex: Int, latitude: Double, longitude: Double, label: String) {
        self.unitIndex = unitIndex
        self.latitude = latitude
        self.longitude = longitude
        self.label = label
    }
}

public struct RouteBoundingRegion: Sendable, Equatable {
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

public enum TrackMapHelper {
    /// Uniformly downsamples long coordinate arrays for responsive MapKit rendering while always preserving first and last points.
    public static func downsample(
        _ coordinates: [PreviewCoordinate],
        maxPoints: Int = 400
    ) -> [PreviewCoordinate] {
        let cap = max(2, maxPoints)
        guard coordinates.count > cap else { return coordinates }

        var result: [PreviewCoordinate] = []
        result.reserveCapacity(cap)
        let lastIndex = coordinates.count - 1
        let step = Double(lastIndex) / Double(cap - 1)
        for i in 0..<(cap - 1) {
            let idx = min(lastIndex, Int((Double(i) * step).rounded()))
            result.append(coordinates[idx])
        }
        result.append(coordinates[lastIndex])
        return result
    }

    /// Computes interpolated km or mile distance markers along an ordered coordinate path.
    public static func distanceMarkers(
        coordinates: [PreviewCoordinate],
        unitSystem: UnitSystem
    ) -> [RouteDistanceMarker] {
        guard coordinates.count >= 2 else { return [] }
        let unitMeters = unitSystem.metersPerMajorUnit
        let suffix = unitSystem.distanceUnitLabel
        var markers: [RouteDistanceMarker] = []

        var cumulative = 0.0
        var nextUnit = 1

        for idx in 1..<coordinates.count {
            let prev = coordinates[idx - 1]
            let curr = coordinates[idx]
            let segLen = GeoMath.distanceMeters(
                lat1: prev.latitude,
                lon1: prev.longitude,
                lat2: curr.latitude,
                lon2: curr.longitude
            )
            guard segLen > 0 else { continue }

            let newCumulative = cumulative + segLen
            while Double(nextUnit) * unitMeters <= newCumulative {
                let targetDist = Double(nextUnit) * unitMeters
                let frac = min(1.0, max(0.0, (targetDist - cumulative) / segLen))
                let lat = prev.latitude + (curr.latitude - prev.latitude) * frac
                let lon = prev.longitude + (curr.longitude - prev.longitude) * frac
                markers.append(
                    RouteDistanceMarker(
                        unitIndex: nextUnit,
                        latitude: lat,
                        longitude: lon,
                        label: "\(nextUnit) \(suffix)"
                    )
                )
                nextUnit += 1
            }
            cumulative = newCumulative
        }

        return markers
    }

    public static func boundingRegion(
        for coordinates: [PreviewCoordinate],
        paddingFactor: Double = 1.35,
        minimumDelta: Double = 0.004
    ) -> RouteBoundingRegion? {
        guard !coordinates.isEmpty else { return nil }
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude

        for coord in coordinates {
            if coord.latitude < minLat { minLat = coord.latitude }
            if coord.latitude > maxLat { maxLat = coord.latitude }
            if coord.longitude < minLon { minLon = coord.longitude }
            if coord.longitude > maxLon { maxLon = coord.longitude }
        }

        return RouteBoundingRegion(
            centerLatitude: (minLat + maxLat) * 0.5,
            centerLongitude: (minLon + maxLon) * 0.5,
            latitudeDelta: max(minimumDelta, (maxLat - minLat) * paddingFactor),
            longitudeDelta: max(minimumDelta, (maxLon - minLon) * paddingFactor)
        )
    }

    /// Returns true if enough time or distance has elapsed to update the live map camera.
    public static func shouldThrottleCameraUpdate(
        lastUpdate: Date?,
        now: Date,
        minimumIntervalSeconds: TimeInterval = 1.5
    ) -> Bool {
        guard let lastUpdate else { return false }
        return now.timeIntervalSince(lastUpdate) < minimumIntervalSeconds
    }
}
