import CoreLocation
import MapKit
import SwiftUI
import TrackerCore

struct FullScreenRecordMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettingsStore.self) private var settings
    @Environment(LocationRecordingService.self) private var recorder

    let onRequestFinish: () -> Void

    @State private var cameraPosition: MapCameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
    @State private var followMode: MapFollowMode = .follow
    @State private var mapStyleOption: MapStyleOption = .standard
    @State private var lastCameraUpdateDate: Date?
    @State private var showingFinishConfirm = false

    private var previewCoordinates: [PreviewCoordinate] {
        recorder.routeCoordinates.map {
            PreviewCoordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private var downsampledCoordinates: [CLLocationCoordinate2D] {
        let sampled = TrackMapHelper.downsample(previewCoordinates, maxPoints: 400)
        return sampled.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var distanceMarkers: [RouteDistanceMarker] {
        TrackMapHelper.distanceMarkers(coordinates: previewCoordinates, unitSystem: settings.unitSystem)
    }

    var body: some View {
        ZStack {
            fullScreenMap
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topOverlayBar
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                Spacer()

                HStack {
                    Spacer()
                    rightControlStack
                }
                .padding(.trailing, 14)
                .padding(.bottom, 12)

                bottomHUD
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .alert("Finish Activity?", isPresented: $showingFinishConfirm) {
            Button("Finish & Review") {
                dismiss()
                onRequestFinish()
            }
            Button("Keep Recording", role: .cancel) {}
        } message: {
            Text("Stop recording and open the save summary screen?")
        }
        .onChange(of: recorder.latestCoordinate?.latitude) { _, _ in
            handleThrottledCameraUpdate()
        }
    }

    @ViewBuilder
    private var fullScreenMap: some View {
        let displayed = downsampledCoordinates
        let markers = distanceMarkers

        Map(position: $cameraPosition) {
            UserAnnotation()

            if let followed = recorder.activeFollowedRoute, followed.waypoints.count >= 2 {
                let guideCoords = followed.waypoints.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                MapPolyline(coordinates: guideCoords)
                    .stroke(RunTheme.violet.opacity(0.75), style: StrokeStyle(lineWidth: 5, dash: [8, 6]))
            }

            if let first = displayed.first {
                Marker("Start", systemImage: "flag.fill", coordinate: first)
                    .tint(RunTheme.emerald)
            }

            if displayed.count >= 2 {
                MapPolyline(coordinates: displayed)
                    .stroke(RunTheme.electricTeal, lineWidth: 5)
            }

            ForEach(markers) { marker in
                Annotation(
                    marker.label,
                    coordinate: CLLocationCoordinate2D(latitude: marker.latitude, longitude: marker.longitude)
                ) {
                    DistanceMilestonePill(label: marker.label)
                }
            }
        }
        .mapStyle(mapStyleOption.mapStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .accessibilityLabel("Full-screen activity recording map")
    }

    @ViewBuilder
    private var topOverlayBar: some View {
        HStack(spacing: 10) {
            MapOverlayControlButton(
                systemImage: "arrow.down.right.and.arrow.up.left",
                accessibilityLabel: "Collapse full-screen map"
            ) {
                dismiss()
            }

            HStack(spacing: 6) {
                Image(systemName: recorder.selectedActivityType.symbolName)
                    .foregroundStyle(RunTheme.electricTeal)
                Text(recorder.state.statusLabel)
                    .font(.subheadline.weight(.bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Spacer()

            if let acc = recorder.latestAccuracyMeters, recorder.state.isActiveSession {
                Text("±\(Int(acc.rounded()))m")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .accessibilityLabel("GPS accuracy plus or minus \(Int(acc.rounded())) meters")
            }
        }
    }

    @ViewBuilder
    private var rightControlStack: some View {
        VStack(spacing: 10) {
            MapOverlayControlButton(
                systemImage: followMode.symbolName,
                accessibilityLabel: "Recenter and follow mode: \(followMode.label)",
                isActive: followMode != .off
            ) {
                cycleFollowMode()
            }

            MapOverlayControlButton(
                systemImage: mapStyleOption.symbolName,
                accessibilityLabel: "Switch map style, current \(mapStyleOption.label)"
            ) {
                mapStyleOption = mapStyleOption.next
            }

            MapOverlayControlButton(
                systemImage: "viewfinder",
                accessibilityLabel: "Zoom to whole route"
            ) {
                zoomToWholeRoute()
            }
            .disabled(recorder.routeCoordinates.count < 2)
            .opacity(recorder.routeCoordinates.count < 2 ? 0.5 : 1.0)
        }
    }

    @ViewBuilder
    private var bottomHUD: some View {
        let unit = settings.unitSystem
        let prefersSpeed = recorder.selectedActivityType.prefersSpeedOverPace
        let rateLabel = prefersSpeed ? "SPEED" : "PACE"
        let rateValue = prefersSpeed
            ? RunFormatter.speed(metersPerSecond: recorder.currentSpeedMPS, unit: unit)
            : RunFormatter.pace(secondsPerMeter: recorder.currentPaceSecondsPerMeter, unit: unit)

        VStack(spacing: 12) {
            HStack(spacing: 8) {
                hudMetric(title: "TIME", value: RunFormatter.duration(seconds: recorder.movingTime), accent: .primary)
                hudMetric(title: "DISTANCE", value: RunFormatter.distance(meters: recorder.distanceMeters, unit: unit), accent: RunTheme.electricTeal)
                hudMetric(title: rateLabel, value: rateValue, accent: RunTheme.emerald)
            }

            if recorder.state.isActiveSession {
                HStack(spacing: 10) {
                    if recorder.state == .recording {
                        Button {
                            recorder.pauseManually()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RunTheme.amber)
                                .foregroundStyle(RunTheme.midnightSlate)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .accessibilityLabel("Pause recording")
                    } else {
                        Button {
                            recorder.resumeManually()
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RunTheme.emerald)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .accessibilityLabel("Resume recording")
                    }

                    Button {
                        showingFinishConfirm = true
                    } label: {
                        Label("Finish", systemImage: "checkmark")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RunTheme.electricTeal)
                            .foregroundStyle(RunTheme.midnightSlate)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityLabel("Finish recording, asks for confirmation")
                }
            } else if recorder.state == .idle {
                Button {
                    recorder.requestStart(settings: settings)
                } label: {
                    Label("Start \(recorder.selectedActivityType.displayName)", systemImage: "play.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RunTheme.electricTeal)
                        .foregroundStyle(RunTheme.midnightSlate)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(recorder.isPermissionDeniedOrRestricted)
                .accessibilityLabel("Start \(recorder.selectedActivityType.displayName)")
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RunTheme.hudBorder.opacity(0.45), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func hudMetric(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.black).monospacedDigit())
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func cycleFollowMode() {
        followMode = followMode.next
        lastCameraUpdateDate = Date()
        if let position = followMode.cameraPosition {
            cameraPosition = position
        }
    }

    private func zoomToWholeRoute() {
        guard let bounds = TrackMapHelper.boundingRegion(for: previewCoordinates) else { return }
        followMode = .off
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: bounds.centerLatitude, longitude: bounds.centerLongitude),
                span: MKCoordinateSpan(latitudeDelta: bounds.latitudeDelta, longitudeDelta: bounds.longitudeDelta)
            )
        )
    }

    private func handleThrottledCameraUpdate() {
        guard followMode == .follow, let coord = recorder.latestCoordinate else { return }
        let now = Date()
        if TrackMapHelper.shouldThrottleCameraUpdate(lastUpdate: lastCameraUpdateDate, now: now, minimumIntervalSeconds: 1.5) {
            return
        }
        lastCameraUpdateDate = now
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.0045, longitudeDelta: 0.0045)
            )
        )
    }
}
