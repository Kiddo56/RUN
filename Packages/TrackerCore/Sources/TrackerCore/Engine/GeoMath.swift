import Foundation

public enum GeoMath {
    public static let earthRadiusMeters: Double = 6_371_000.0

    public static func distanceMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let phi1 = lat1 * .pi / 180.0
        let phi2 = lat2 * .pi / 180.0
        let dPhi = (lat2 - lat1) * .pi / 180.0
        let dLambda = (lon2 - lon1) * .pi / 180.0

        let sinDPhi = sin(dPhi * 0.5)
        let sinDLambda = sin(dLambda * 0.5)
        let aRaw = sinDPhi * sinDPhi + cos(phi1) * cos(phi2) * sinDLambda * sinDLambda
        let a = min(1.0, max(0.0, aRaw))
        let c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
        return earthRadiusMeters * c
    }

    public static func distanceMeters(from a: TrackPoint, to b: TrackPoint) -> Double {
        distanceMeters(lat1: a.latitude, lon1: a.longitude, lat2: b.latitude, lon2: b.longitude)
    }

    public static func bearingDegrees(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let phi1 = lat1 * .pi / 180.0
        let phi2 = lat2 * .pi / 180.0
        let dLambda = (lon2 - lon1) * .pi / 180.0

        let y = sin(dLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dLambda)
        let theta = atan2(y, x) * 180.0 / .pi
        let normalized = theta.truncatingRemainder(dividingBy: 360.0)
        return normalized >= 0 ? normalized : normalized + 360.0
    }

    public static func angleDifferenceDegrees(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b).truncatingRemainder(dividingBy: 360.0)
        return diff > 180.0 ? 360.0 - diff : diff
    }

    /// Shortest Euclidean distance in meters from `point` to segment (`segmentStart` -> `segmentEnd`)
    /// using a local tangent-plane projection centered at `segmentStart`.
    public static func crossTrackDistanceMeters(
        point: (latitude: Double, longitude: Double),
        segmentStart: (latitude: Double, longitude: Double),
        segmentEnd: (latitude: Double, longitude: Double)
    ) -> Double {
        let refLatRad = segmentStart.latitude * .pi / 180.0
        let metersPerDegLat = (.pi / 180.0) * earthRadiusMeters
        let metersPerDegLon = metersPerDegLat * max(1e-6, cos(refLatRad))

        let px = (point.longitude - segmentStart.longitude) * metersPerDegLon
        let py = (point.latitude - segmentStart.latitude) * metersPerDegLat

        let bx = (segmentEnd.longitude - segmentStart.longitude) * metersPerDegLon
        let by = (segmentEnd.latitude - segmentStart.latitude) * metersPerDegLat

        let segLenSq = bx * bx + by * by
        if segLenSq <= 1e-9 {
            return hypot(px, py)
        }

        let t = min(1.0, max(0.0, (px * bx + py * by) / segLenSq))
        let projX = t * bx
        let projY = t * by
        return hypot(px - projX, py - projY)
    }
}
