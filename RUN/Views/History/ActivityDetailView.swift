import MapKit
import SwiftData
import SwiftUI
import TrackerCore

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @Bindable var activity: SDActivity
    @Query private var allGear: [SDGear]

    @State private var points: [TrackPoint] = []
    @State private var chartSamples: [TrackChartSample] = []
    @State private var coloredSegments: [ColoredTrackSegment] = []
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var scrubbedDistanceUnit: Double?
    @State private var loadError: String?

    @State private var showingEditSheet = false
    @State private var showingTrimSheet = false
    @State private var showingMergeSheet = false
    @State private var showingShareSheet = false
    @State private var showingFullScreenMap = false
    @State private var exportedGPXURL: URL?
    @State private var showingGPXExportSheet = false
    @State private var showingDeleteConfirm = false

    private var selectedSample: TrackChartSample? {
        guard let scrubbedDistanceUnit else { return nil }
        let targetMeters = scrubbedDistanceUnit * settings.unitSystem.metersPerMajorUnit
        return TrackChartBuilder.nearestSample(in: chartSamples, toDistanceMeters: targetMeters)
    }

    private var assignedGearName: String? {
        guard let gearID = activity.gearID else { return nil }
        return allGear.first(where: { $0.id == gearID })?.name
    }

    private var reloadToken: String {
        "\(activity.id.uuidString)-\(activity.pointCount)-\(Int(activity.distanceMeters.rounded()))-\(settings.unitSystem.rawValue)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerBanner
                routeMapSection
                statsGridSection

                if !activity.notes.isEmpty {
                    notesCard
                }

                if !chartSamples.isEmpty {
                    ActivityChartsSection(
                        samples: chartSamples,
                        activityType: activity.activityType,
                        unitSystem: settings.unitSystem,
                        scrubbedDistanceUnit: $scrubbedDistanceUnit,
                        selectedSample: selectedSample
                    )
                }

                splitsSection
            }
            .padding(16)
        }
        .navigationTitle(activity.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share Activity Card")
                .disabled(points.isEmpty)

                Menu {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share Activity Card", systemImage: "square.and.arrow.up")
                    }
                    .disabled(points.isEmpty)

                    Button {
                        if let url = try? DataTransferService.exportSingleGPX(activity: activity) {
                            exportedGPXURL = url
                            showingGPXExportSheet = true
                        }
                    } label: {
                        Label("Export GPX 1.1", systemImage: "doc.text")
                    }
                    .disabled(points.isEmpty)

                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Details", systemImage: "pencil")
                    }

                    Button {
                        showingTrimSheet = true
                    } label: {
                        Label("Trim Route", systemImage: "scissors")
                    }
                    .disabled(points.count < 4)

                    Button {
                        showingMergeSheet = true
                    } label: {
                        Label("Merge With Activity", systemImage: "arrow.triangle.merge")
                    }
                    .disabled(points.count < 2)

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Activity", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Activity actions")
            }
        }
        .task(id: reloadToken) {
            loadTrackData()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditActivitySheet(activity: activity)
        }
        .sheet(isPresented: $showingTrimSheet) {
            TrimActivitySheet(activity: activity, points: points)
        }
        .sheet(isPresented: $showingMergeSheet) {
            MergeActivitySheet(activity: activity, primaryPoints: points)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareCardSheet(activity: activity, points: points)
        }
        .fullScreenCover(isPresented: $showingFullScreenMap) {
            FullScreenActivityMapView(
                activity: activity,
                points: points,
                coloredSegments: coloredSegments,
                chartSamples: chartSamples,
                scrubbedDistanceUnit: $scrubbedDistanceUnit
            )
        }
        .sheet(isPresented: $showingGPXExportSheet) {
            NavigationStack {
                VStack(spacing: 18) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 48))
                        .foregroundStyle(RunTheme.electricTeal)
                    Text("GPX 1.1 Ready")
                        .font(.title3.weight(.bold))
                    Text("\(activity.title) (\(points.count) points)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let exportedGPXURL {
                        ShareLink(item: exportedGPXURL) {
                            Label("Save / Share .gpx File", systemImage: "square.and.arrow.up")
                                .font(.headline.weight(.bold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(RunTheme.electricTeal)
                                .foregroundStyle(RunTheme.midnightSlate)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding()
                .navigationTitle("Export GPX")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showingGPXExportSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Delete Activity?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                TrackFileStore.shared.deleteTrackFile(fileName: activity.trackFileName)
                modelContext.delete(activity)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This activity and its GPS track will be permanently deleted.")
        }
    }

    @ViewBuilder
    private var headerBanner: some View {
        HStack {
            Label(activity.activityType.displayName, systemImage: activity.activityType.symbolName)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RunTheme.electricTeal.opacity(0.16))
                .foregroundStyle(RunTheme.electricTeal)
                .clipShape(Capsule())

            Spacer()

            Text(activity.startDate.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var routeMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(RunTheme.coral)
            }

            ZStack(alignment: .bottomTrailing) {
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
                        Marker("Start", systemImage: "flag.fill", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude))
                            .tint(RunTheme.emerald)
                    }

                    if let last = points.last, points.count > 1 {
                        Marker("Finish", systemImage: "flag.checkered", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude))
                            .tint(RunTheme.coral)
                    }

                    if let selected = selectedSample {
                        Annotation(
                            "Inspect",
                            coordinate: CLLocationCoordinate2D(latitude: selected.latitude, longitude: selected.longitude)
                        ) {
                            Circle()
                                .fill(RunTheme.amber)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(.white, lineWidth: 3))
                                .shadow(radius: 4)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RunTheme.hudBorder.opacity(0.45), lineWidth: 1)
                )

                if points.count >= 2 {
                    Button {
                        showingFullScreenMap = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RunTheme.electricTeal)
                            .padding(10)
                            .background(RunTheme.hudSurface.opacity(0.92))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(10)
                    .accessibilityLabel("Expand full-screen activity map")
                }
            }

            HStack(spacing: 8) {
                Text(activity.activityType.prefersSpeedOverPace ? "Speed:" : "Pace:")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Slow")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                LinearGradient(
                    colors: [RunTheme.violet, RunTheme.electricTeal, RunTheme.emerald],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 90, height: 6)
                .clipShape(Capsule())
                Text("Fast")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(activity.pointCount) pts")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statsGridSection: some View {
        let unit = settings.unitSystem
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        LazyVGrid(columns: columns, spacing: 10) {
            detailStatCard(title: "DISTANCE", value: RunFormatter.distance(meters: activity.distanceMeters, unit: unit), accent: RunTheme.electricTeal)
            detailStatCard(title: "MOVING TIME", value: RunFormatter.duration(seconds: activity.movingTime), accent: .primary)
            detailStatCard(title: "ELAPSED TIME", value: RunFormatter.duration(seconds: activity.elapsedTime), accent: .secondary)

            if activity.activityType.prefersSpeedOverPace {
                detailStatCard(title: "AVG SPEED", value: RunFormatter.speed(metersPerSecond: activity.averageSpeedMPS, unit: unit), accent: RunTheme.emerald)
            } else {
                detailStatCard(title: "AVG PACE", value: RunFormatter.pace(secondsPerMeter: activity.averagePaceSecondsPerMeter, unit: unit), accent: RunTheme.emerald)
            }

            detailStatCard(title: "ELEVATION GAIN", value: RunFormatter.elevation(meters: activity.elevationGainMeters, unit: unit), accent: RunTheme.violet)
            detailStatCard(title: "ELEVATION LOSS", value: RunFormatter.elevation(meters: activity.elevationLossMeters, unit: unit), accent: .secondary)
            detailStatCard(title: "EFFORT SCORE (EST.)", value: "\(Int(activity.effortScore.rounded()))", accent: RunTheme.electricTeal)
            detailStatCard(title: "CALORIES (EST.)", value: "\(Int(activity.estimatedCalories.rounded())) kcal", accent: .primary)

            if let avgHR = activity.averageHeartRate {
                detailStatCard(title: "AVG HR", value: "\(Int(avgHR.rounded())) bpm", accent: RunTheme.coral)
            }
            if let maxHR = activity.maxHeartRate {
                detailStatCard(title: "MAX HR", value: "\(Int(maxHR.rounded())) bpm", accent: RunTheme.coral)
            }
            if let gearName = assignedGearName {
                detailStatCard(title: "GEAR", value: gearName, accent: RunTheme.electricTeal)
            }
        }
    }

    @ViewBuilder
    private func detailStatCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(activity.notes)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var splitsSection: some View {
        let splits = activity.decodedSplits()
        let fastestID = splits.filter { !$0.isPartial && $0.movingSeconds > 0 }
            .min(by: { $0.paceSecondsPerMeter < $1.paceSecondsPerMeter })?.id
        let unit = settings.unitSystem

        VStack(alignment: .leading, spacing: 10) {
            Text("Splits")
                .font(.headline)

            if splits.isEmpty {
                Text("No split data available for this activity.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(splits) { split in
                        HStack(spacing: 8) {
                            Text(split.isPartial ? "\(split.index)*" : "\(split.index)")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(split.id == fastestID ? RunTheme.emerald : .secondary)
                                .frame(width: 28, alignment: .leading)

                            Text(RunFormatter.distance(meters: split.distanceMeters, unit: unit))
                                .font(.caption.monospacedDigit())
                                .frame(width: 68, alignment: .leading)

                            if activity.activityType.prefersSpeedOverPace {
                                Text(RunFormatter.speed(metersPerSecond: split.speedMPS, unit: unit))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(split.id == fastestID ? RunTheme.emerald : .primary)
                            } else {
                                Text(RunFormatter.pace(secondsPerMeter: split.paceSecondsPerMeter, unit: unit))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(split.id == fastestID ? RunTheme.emerald : .primary)
                            }

                            Spacer()

                            Text("+\(RunFormatter.elevation(meters: split.elevationGainMeters, unit: unit))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(RunTheme.violet)

                            Text(RunFormatter.duration(seconds: split.movingSeconds))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 52, alignment: .trailing)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)

                        if split.id != splits.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func loadTrackData() {
        loadError = nil
        do {
            let loaded = try TrackFileStore.shared.loadTrackPoints(fileName: activity.trackFileName)
            points = loaded
            chartSamples = TrackChartBuilder.buildSamples(points: loaded, unitSystem: settings.unitSystem)
            coloredSegments = TrackChartBuilder.buildColoredSegments(points: loaded)
            if let region = fitRegion(for: loaded) {
                cameraPosition = .region(region)
            }
        } catch {
            points = []
            chartSamples = []
            coloredSegments = []
            loadError = "Track file missing or unreadable."
        }
    }

    private func fitRegion(for track: [TrackPoint]) -> MKCoordinateRegion? {
        guard !track.isEmpty else { return nil }
        let lats = track.map(\.latitude)
        let lons = track.map(\.longitude)
        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLon = lons.min(),
              let maxLon = lons.max() else { return nil }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) * 0.5,
            longitude: (minLon + maxLon) * 0.5
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.003, (maxLat - minLat) * 1.35),
            longitudeDelta: max(0.003, (maxLon - minLon) * 1.35)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private func segmentColor(intensity: Double) -> Color {
        let t = min(1.0, max(0.0, intensity))
        if t < 0.5 {
            let local = t * 2.0
            return Color(
                red: (139.0 * (1.0 - local) + 0.0 * local) / 255.0,
                green: (92.0 * (1.0 - local) + 212.0 * local) / 255.0,
                blue: (246.0 * (1.0 - local) + 229.0 * local) / 255.0
            )
        } else {
            let local = (t - 0.5) * 2.0
            return Color(
                red: (0.0 * (1.0 - local) + 16.0 * local) / 255.0,
                green: (212.0 * (1.0 - local) + 185.0 * local) / 255.0,
                blue: (229.0 * (1.0 - local) + 129.0 * local) / 255.0
            )
        }
    }
}
