import MapKit
import SwiftUI
import TrackerCore
import UIKit

@MainActor
enum ShareCardRenderer {
    static func renderCard(
        activity: SDActivity,
        points: [TrackPoint],
        unitSystem: UnitSystem,
        hideEndpoints: Bool,
        hideMeters: Double
    ) async -> UIImage? {
        let displayedCoords: [CLLocationCoordinate2D]
        if hideEndpoints {
            displayedCoords = TrackPrivacyTrimmer.trimEndpoints(points: points, hideMeters: hideMeters)
                .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        } else {
            displayedCoords = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }

        let region = fitRegion(for: displayedCoords)
        let mapSize = CGSize(width: 960, height: 640)

        let options = MKMapSnapshotter.Options()
        options.size = mapSize
        options.scale = 2.0
        options.region = region
        options.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)

        let snapshot: MKMapSnapshotter.Snapshot
        do {
            snapshot = try await MKMapSnapshotter(options: options).start()
        } catch {
            DiagnosticsLogger.shared.log(.error, "MKMapSnapshotter failed: \(error.localizedDescription)")
            return nil
        }

        let canvasSize = CGSize(width: 960, height: 1040)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let slate = UIColor(red: 11.0 / 255.0, green: 19.0 / 255.0, blue: 43.0 / 255.0, alpha: 1.0)
            let surface = UIColor(red: 19.0 / 255.0, green: 30.0 / 255.0, blue: 58.0 / 255.0, alpha: 1.0)
            let teal = UIColor(red: 0.0 / 255.0, green: 212.0 / 255.0, blue: 229.0 / 255.0, alpha: 1.0)
            let emerald = UIColor(red: 16.0 / 255.0, green: 185.0 / 255.0, blue: 129.0 / 255.0, alpha: 1.0)
            let coral = UIColor(red: 239.0 / 255.0, green: 68.0 / 255.0, blue: 68.0 / 255.0, alpha: 1.0)
            let muted = UIColor(red: 148.0 / 255.0, green: 163.0 / 255.0, blue: 184.0 / 255.0, alpha: 1.0)

            slate.setFill()
            cg.fill(CGRect(origin: .zero, size: canvasSize))

            snapshot.image.draw(in: CGRect(origin: .zero, size: mapSize))

            // Draw polyline onto map snapshot
            if displayedCoords.count >= 2 {
                let path = UIBezierPath()
                for (idx, coord) in displayedCoords.enumerated() {
                    let pt = snapshot.point(for: coord)
                    if idx == 0 {
                        path.move(to: pt)
                    } else {
                        path.addLine(to: pt)
                    }
                }
                path.lineCapStyle = .round
                path.lineJoinStyle = .round

                teal.withAlphaComponent(0.28).setStroke()
                path.lineWidth = 14
                path.stroke()

                teal.setStroke()
                path.lineWidth = 6
                path.stroke()
            }

            if !hideEndpoints, let startCoord = displayedCoords.first, let endCoord = displayedCoords.last {
                drawMarkerDot(at: snapshot.point(for: startCoord), color: emerald)
                if displayedCoords.count > 1 {
                    drawMarkerDot(at: snapshot.point(for: endCoord), color: coral)
                }
            }

            // Bottom fade over map into footer card
            let colors = [slate.withAlphaComponent(0.0).cgColor, slate.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 500),
                    end: CGPoint(x: 0, y: 640),
                    options: []
                )
            }

            // Footer panel
            surface.setFill()
            let panelRect = CGRect(x: 32, y: 656, width: 896, height: 352)
            let panelPath = UIBezierPath(roundedRect: panelRect, cornerRadius: 24)
            panelPath.fill()

            let tagAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .heavy),
                .foregroundColor: teal
            ]
            NSString(string: "RUN · \(activity.activityType.displayName.uppercased())").draw(at: CGPoint(x: 64, y: 684), withAttributes: tagAttrs)

            let dateStr = activity.startDate.formatted(date: .abbreviated, time: .shortened)
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: muted
            ]
            NSString(string: dateStr).draw(at: CGPoint(x: 64, y: 718), withAttributes: dateAttrs)

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 38, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            NSString(string: activity.title).draw(in: CGRect(x: 64, y: 752, width: 832, height: 48), withAttributes: titleAttrs)

            let rateLabel = activity.activityType.prefersSpeedOverPace ? "AVG SPEED" : "AVG PACE"
            let rateValue = activity.activityType.prefersSpeedOverPace
                ? RunFormatter.speed(metersPerSecond: activity.averageSpeedMPS, unit: unitSystem)
                : RunFormatter.pace(secondsPerMeter: activity.averagePaceSecondsPerMeter, unit: unitSystem)

            let cols: [(String, String, UIColor)] = [
                ("DISTANCE", RunFormatter.distance(meters: activity.distanceMeters, unit: unitSystem), teal),
                ("MOVING TIME", RunFormatter.duration(seconds: activity.movingTime), .white),
                (rateLabel, rateValue, emerald),
                ("ELEV GAIN", RunFormatter.elevation(meters: activity.elevationGainMeters, unit: unitSystem), .white)
            ]

            for (idx, col) in cols.enumerated() {
                let x = 64.0 + Double(idx) * 212.0
                drawStatColumn(label: col.0, value: col.1, valueColor: col.2, labelColor: muted, x: x, y: 830)
            }

            let estText = "Est. \(Int(activity.estimatedCalories.rounded())) kcal · Effort \(Int(activity.effortScore.rounded()))"
            let footerText = hideEndpoints
                ? "\(estText)  |  First & last \(Int(hideMeters.rounded())) m hidden"
                : estText
            NSString(string: footerText).draw(at: CGPoint(x: 64, y: 952), withAttributes: dateAttrs)
        }
    }

    static func writeTemporaryPNG(_ image: UIImage, activityID: UUID) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RUN-Share-\(activityID.uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func drawMarkerDot(at point: CGPoint, color: UIColor) {
        let outer = UIBezierPath(ovalIn: CGRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22))
        UIColor.white.setFill()
        outer.fill()

        let inner = UIBezierPath(ovalIn: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16))
        color.setFill()
        inner.fill()
    }

    private static func drawStatColumn(
        label: String,
        value: String,
        valueColor: UIColor,
        labelColor: UIColor,
        x: Double,
        y: Double
    ) {
        let lAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: labelColor
        ]
        let vAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 30, weight: .bold),
            .foregroundColor: valueColor
        ]
        NSString(string: label).draw(at: CGPoint(x: x, y: y), withAttributes: lAttrs)
        NSString(string: value).draw(at: CGPoint(x: x, y: y + 26), withAttributes: vAttrs)
    }

    private static func fitRegion(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coords.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) * 0.5, longitude: (minLon + maxLon) * 0.5),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.004, (maxLat - minLat) * 1.45),
                longitudeDelta: max(0.004, (maxLon - minLon) * 1.45)
            )
        )
    }
}
