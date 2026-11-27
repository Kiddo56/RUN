import CoreLocation
import MapKit
import SwiftData
import SwiftUI
import TrackerCore

private extension HeatmapTrack {
    var clCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
}

struct PersonalHeatmapView: View {
    @Environment(AppSettingsStore.self) private var settings

    @Query(sort: \SDActivity.startDate, order: .reverse) private var activities: [SDActivity]

    @State private var selectedType: ActivityType?
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var summary: HeatmapSummary {
        let inputs = activities.map {
            HeatmapTrackInput(
                id: $0.id,
                activityType: $0.activityType,
                coordinates: $0.decodedPreviewCoordinates()
            )
        }
        return HeatmapBuilder.build(inputs: inputs, activityTypeFilter: selectedType, maxPointsPerTrack: 80)
    }

    private var filteredTotalDistanceMeters: Double {
        activities
            .filter { selectedType == nil || $0.activityType == selectedType }
            .reduce(0.0) { $0 + $1.distanceMeters }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            ZStack(alignment: .bottom) {
                heatmapCanvas
                summaryBanner
            }
        }
        .navigationTitle("Personal Heatmap")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fitToTracks()
        }
        .onChange(of: selectedType) { _, _ in
            fitToTracks()
        }
    }

    @ViewBuilder
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(title: "All", type: nil)
                ForEach(ActivityType.gpsCases) { type in
                    filterPill(title: type.displayName, type: type)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func filterPill(title: String, type: ActivityType?) -> some View {
        let isSelected = selectedType == type
        Button {
            selectedType = type
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? RunTheme.electricTeal : Color.secondary.opacity(0.16))
                .foregroundStyle(isSelected ? RunTheme.midnightSlate : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var heatmapCanvas: some View {
        let tracks = summary.tracks
        Map(position: $cameraPosition) {
            ForEach(tracks) { track in
                let coords = track.clCoordinates
                MapPolyline(coordinates: coords)
                    .stroke(RunTheme.electricTeal.opacity(0.22), lineWidth: 7)
                MapPolyline(coordinates: coords)
                    .stroke(RunTheme.electricTeal.opacity(0.45), lineWidth: 2.5)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .overlay {
            if tracks.isEmpty {
                ContentUnavailableView(
                    "No Tracks to Display",
                    systemImage: "map",
                    description: Text("Record or import activities to see your personal route heatmap.")
                )
                .background(.ultraThinMaterial)
            }
        }
    }

    @ViewBuilder
    private var summaryBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(summary.tracks.count) personal track\(summary.tracks.count == 1 ? "" : "s")")
                    .font(.caption.weight(.bold))
                Text(RunFormatter.distance(meters: filteredTotalDistanceMeters, unit: settings.unitSystem))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if summary.bounds != nil {
                Button("Fit All") {
                    fitToTracks()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(RunTheme.electricTeal)
                .foregroundStyle(RunTheme.midnightSlate)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(14)
    }

    private func fitToTracks() {
        guard let bounds = summary.bounds else { return }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: bounds.centerLatitude, longitude: bounds.centerLongitude),
                span: MKCoordinateSpan(latitudeDelta: bounds.latitudeDelta, longitudeDelta: bounds.longitudeDelta)
            )
        )
    }
}
