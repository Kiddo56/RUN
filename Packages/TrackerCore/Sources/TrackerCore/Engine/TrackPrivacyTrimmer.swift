import Foundation

public enum TrackPrivacyTrimmer {
    public static func trimEndpoints(
        points: [TrackPoint],
        hideMeters: Double = 200.0
    ) -> [PreviewCoordinate] {
        guard points.count >= 2, hideMeters > 0 else {
            return points.map { PreviewCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        }

        var cumDist: [Double] = [0.0]
        cumDist.reserveCapacity(points.count)
        for i in 1..<points.count {
            cumDist.append(cumDist[i - 1] + GeoMath.distanceMeters(from: points[i - 1], to: points[i]))
        }

        let total = cumDist.last ?? 0.0
        guard total > 0 else {
            return points.map { PreviewCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        }

        let lowerBound: Double
        let upperBound: Double
        if total > hideMeters * 2.2 {
            lowerBound = hideMeters
            upperBound = total - hideMeters
        } else {
            lowerBound = total * 0.25
            upperBound = total * 0.75
        }

        var kept: [PreviewCoordinate] = []
        for (idx, pt) in points.enumerated() {
            if cumDist[idx] >= lowerBound && cumDist[idx] <= upperBound {
                kept.append(PreviewCoordinate(latitude: pt.latitude, longitude: pt.longitude))
            }
        }

        if kept.count < 2 {
            let mid = points.count / 2
            let lo = max(0, mid - 1)
            let hi = min(points.count - 1, mid + 1)
            return points[lo...hi].map { PreviewCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        }
        return kept
    }
}
