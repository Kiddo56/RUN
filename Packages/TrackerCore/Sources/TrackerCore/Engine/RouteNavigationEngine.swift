import Foundation

public struct RouteFollowStatus: Sendable, Equatable {
    public let distanceOffRouteMeters: Double
    public let isOffRoute: Bool
    public let remainingDistanceMeters: Double
    public let nearestSegmentIndex: Int

    public init(
        distanceOffRouteMeters: Double,
        isOffRoute: Bool,
        remainingDistanceMeters: Double,
        nearestSegmentIndex: Int
    ) {
        self.distanceOffRouteMeters = distanceOffRouteMeters
        self.isOffRoute = isOffRoute
        self.remainingDistanceMeters = remainingDistanceMeters
        self.nearestSegmentIndex = nearestSegmentIndex
    }
}

public enum RouteNavigationEngine {
    public static func totalDistanceMeters(waypoints: [RouteWaypoint]) -> Double {
        guard waypoints.count >= 2 else { return 0.0 }
        var total = 0.0
        for idx in 1..<waypoints.count {
            total += GeoMath.distanceMeters(
                lat1: waypoints[idx - 1].latitude,
                lon1: waypoints[idx - 1].longitude,
                lat2: waypoints[idx].latitude,
                lon2: waypoints[idx].longitude
            )
        }
        return total
    }

    public static func evaluate(
        latitude: Double,
        longitude: Double,
        waypoints: [RouteWaypoint],
        offRouteThresholdMeters: Double = 50.0
    ) -> RouteFollowStatus {
        guard !waypoints.isEmpty else {
            return RouteFollowStatus(
                distanceOffRouteMeters: 0,
                isOffRoute: false,
                remainingDistanceMeters: 0,
                nearestSegmentIndex: 0
            )
        }

        if waypoints.count == 1 {
            let d = GeoMath.distanceMeters(
                lat1: latitude,
                lon1: longitude,
                lat2: waypoints[0].latitude,
                lon2: waypoints[0].longitude
            )
            return RouteFollowStatus(
                distanceOffRouteMeters: d,
                isOffRoute: d > offRouteThresholdMeters,
                remainingDistanceMeters: d,
                nearestSegmentIndex: 0
            )
        }

        var minDistance = Double.greatestFiniteMagnitude
        var nearestIndex = 0

        for idx in 0..<(waypoints.count - 1) {
            let a = waypoints[idx]
            let b = waypoints[idx + 1]
            let d = GeoMath.crossTrackDistanceMeters(
                point: (latitude: latitude, longitude: longitude),
                segmentStart: (latitude: a.latitude, longitude: a.longitude),
                segmentEnd: (latitude: b.latitude, longitude: b.longitude)
            )
            if d < minDistance {
                minDistance = d
                nearestIndex = idx
            }
        }

        let segEnd = waypoints[nearestIndex + 1]
        var remaining = GeoMath.distanceMeters(
            lat1: latitude,
            lon1: longitude,
            lat2: segEnd.latitude,
            lon2: segEnd.longitude
        )
        if nearestIndex + 1 < waypoints.count - 1 {
            for idx in (nearestIndex + 1)..<(waypoints.count - 1) {
                remaining += GeoMath.distanceMeters(
                    lat1: waypoints[idx].latitude,
                    lon1: waypoints[idx].longitude,
                    lat2: waypoints[idx + 1].latitude,
                    lon2: waypoints[idx + 1].longitude
                )
            }
        }

        return RouteFollowStatus(
            distanceOffRouteMeters: minDistance,
            isOffRoute: minDistance > offRouteThresholdMeters,
            remainingDistanceMeters: remaining,
            nearestSegmentIndex: nearestIndex
        )
    }
}
