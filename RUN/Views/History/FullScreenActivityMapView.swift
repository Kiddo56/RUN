import CoreLocation
import MapKit
import SwiftUI
import TrackerCore

struct FullScreenActivityMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettingsStore.self) private var settings

    let activity: SDActivity
    let points: [TrackPoint]
    let coloredSegments: [ColoredTrackSegment]
    let chartSamples: [TrackChartSample]
    @Binding var scrubbedDistanceUnit: Double?

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapStyleOption: MapStyleOption = .standard
    @State private var showDistanceMarkers = true

    private var previewCoordinates: [PreviewCoordinate] {
        points.map { PreviewCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var distanceMarkers: [RouteDistanceMarker] {
        TrackMapHelper.distanceMarkers(coordinates: previewCoordinates, unitSystem: settings.unitSystem)
    }

    private var maxDistanceUnit: Double {
        let lastMeters = chartSamples.last?.distanceMeters ?? activity.distanceMeters
        return max(0.01, lastMeters / settings.unitSystem.metersPerMajorUnit)
    }

    private var selectedSample: TrackChartSample? {
        guard let scrubbedDistanceUnit else { return nil }
        let targetMeters = scrubbedDistanceUnit * settings.unitSystem.metersPerMajorUnit
        return TrackChartBuilder.nearestSample(in: chartSamples, toDistanceMeters: targetMeters)
    }

    var body: some View {
        ZStack {
            detailMap
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                Spacer()

                HStack {
                    Spacer()
                    controlStack
                }
                .padding(.trailing, 14)
                .padding(.bottom, 12)

                if !chartSamples.isEmpty {
                    scrubberHUD
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
        }
        .onAppear {
            zoomToWholeRoute()
        }
    }

    @ViewBuilder
    private var detailMap: some View {
        let markers = showDistanceMarkers ? distanceMarkers : []

        Map(position: $cameraPosition) {
            ForEach(coloredSegments) { segment in
                let coords = segment.coordinates.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                if coords.count >= 2 {
                    MapPolyline(coordinates: coords)
                        .stroke(segmentColor(intensity: segment.intensityNormalized), lineWidth: 5)
                }
            }

            if let first = points.first {
                Marker(
                    "Start",
                    systemImage: "flag.fill",
                    coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
                )
                .tint(RunTheme.emerald)
            }

            if let last = points.last, points.count > 1 {
                Marker(
                    "Finish",
                    systemImage: "flag.checkered",
                    coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)
                )
                .tint(RunTheme.coral)
            }

            ForEach(markers) { marker in
                Annotation(
                    marker.label,
                    coordinate: CLLocationCoordinate2D(latitude: marker.latitude, longitude: marker.longitude)
                ) {
                    DistanceMilestonePill(label: marker.label)
                }
            }

            if let selected = selectedSample {
                Annotation(
                    "Inspect",
                    coordinate: CLLocationCoordinate2D(latitude: selected.latitude, longitude: selected.longitude)
                ) {
                    Circle()
                        .fill(RunTheme.amber)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 5)
                }
            }
        }
        .mapStyle(mapStyleOption.mapStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .accessibilityLabel("Full-screen activity detail map")
    }

    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: 10) {
            MapOverlayControlButton(
                systemImage: "arrow.down.right.and.arrow.up.left",
                accessibilityLabel: "Collapse full-screen map"
            ) {
                dismiss()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text(RunFormatter.distance(meters: activity.distanceMeters, unit: settings.unitSystem))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Spacer()
        }
    }

    @ViewBuilder
    private var controlStack: some View {
        VStack(spacing: 10) {
            MapOverlayControlButton(
                systemImage: mapStyleOption.symbolName,
                accessibilityLabel: "Switch map style, current \(mapStyleOption.label)"
            ) {
                mapStyleOption = mapStyleOption.next
            }

            MapOverlayControlButton(
                systemImage: "number.circle",
                accessibilityLabel: showDistanceMarkers ? "Hide distance markers" : "Show distance markers",
                isActive: showDistanceMarkers
            ) {
                showDistanceMarkers.toggle()
            }

            MapOverlayControlButton(
                systemImage: "viewfinder",
                accessibilityLabel: "Zoom to whole route"
            ) {
                zoomToWholeRoute()
            }
        }
    }

    @ViewBuilder
    private var scrubberHUD: some View {
        let unit = settings.unitSystem
        let sliderBinding = Binding<Double>(
            get: { scrubbedDistanceUnit ?? 0 },
            set: { scrubbedDistanceUnit = $0 }
        )

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let sample = selectedSample {
                    let paceSPM = sample.speedMPS > 0 ? (1.0 / sample.speedMPS) : 0
                    let rate = activity.activityType.prefersSpeedOverPace
                        ? RunFormatter.speed(metersPerSecond: sample.speedMPS, unit: unit)
                        : RunFormatter.pace(secondsPerMeter: paceSPM, unit: unit)
                    Text("\(RunFormatter.distance(meters: sample.distanceMeters, unit: unit)) · \(rate) · \(RunFormatter.elevation(meters: sample.altitudeMeters, unit: unit))")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(RunTheme.electricTeal)
                        .lineLimit(1)
                } else {
                    Text("Scrub route to inspect point on map")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if scrubbedDistanceUnit != nil {
                    Button("Clear") {
                        scrubbedDistanceUnit = nil
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            Slider(value: sliderBinding, in: 0...maxDistanceUnit)
                .tint(RunTheme.amber)
                .accessibilityLabel("Scrub route position")
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RunTheme.hudBorder.opacity(0.45), lineWidth: 1)
        )
    }

    private func zoomToWholeRoute() {
        guard let bounds = TrackMapHelper.boundingRegion(for: previewCoordinates) else { return }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: bounds.centerLatitude, longitude: bounds.centerLongitude),
                span: MKCoordinateSpan(latitudeDelta: bounds.latitudeDelta, longitudeDelta: bounds.longitudeDelta)
            )
        )
    }

    private func segmentColor(intensity: Double) -> Color {
        if intensity < 0.35 {
            return RunTheme.violet
        } else if intensity < 0.72 {
            return RunTheme.electricTeal
        } else {
            return RunTheme.emerald
        }
    }
}
