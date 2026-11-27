import CoreLocation
import MapKit
import SwiftData
import SwiftUI
import TrackerCore

struct PersonalSectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @Query(sort: \SDSection.createdAt, order: .reverse) private var sections: [SDSection]

    @State private var showingBuilder = false

    var body: some View {
        List {
            if sections.isEmpty {
                ContentUnavailableView(
                    "No Personal Sections Yet",
                    systemImage: "flag.checkered.2.crossed",
                    description: Text("Drop Start and End pins on the map to automatically match and rank your own past and future efforts across those gates.")
                )
            } else {
                ForEach(sections) { section in
                    NavigationLink(destination: SectionDetailView(section: section)) {
                        sectionRow(section)
                    }
                }
                .onDelete(perform: deleteSections)
            }
        }
        .navigationTitle("Personal Sections")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingBuilder = true
                } label: {
                    Label("New Section", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingBuilder) {
            SectionBuilderSheet()
        }
    }

    @ViewBuilder
    private func sectionRow(_ section: SDSection) -> some View {
        let type = ActivityType(rawValue: section.activityTypeRaw) ?? .run
        HStack(spacing: 12) {
            Image(systemName: type.symbolName)
                .foregroundStyle(RunTheme.amber)
                .frame(width: 34, height: 34)
                .background(RunTheme.amber.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(section.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(type.displayName)
                    Text("·")
                    Text(RunFormatter.distance(meters: section.distanceMeters, unit: settings.unitSystem))
                    Text("·")
                    Text("±\(Int(section.corridorMeters.rounded()))m gate")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func deleteSections(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sections[index])
        }
        try? modelContext.save()
    }
}

private struct SectionBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var name = ""
    @State private var activityType: ActivityType = .run
    @State private var startCoord: CLLocationCoordinate2D?
    @State private var endCoord: CLLocationCoordinate2D?
    @State private var corridorMeters: Double = 35.0

    private var straightDistanceMeters: Double {
        guard let startCoord, let endCoord else { return 0 }
        return GeoMath.distanceMeters(
            lat1: startCoord.latitude,
            lon1: startCoord.longitude,
            lat2: endCoord.latitude,
            lon2: endCoord.longitude
        )
    }

    private var canSave: Bool {
        startCoord != nil && endCoord != nil && straightDistanceMeters >= 20.0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                builderMap
                builderControls
            }
            .navigationTitle("New Personal Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSection() }
                        .disabled(!canSave)
                }
            }
        }
    }

    @ViewBuilder
    private var builderMap: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                UserAnnotation()
                if let startCoord {
                    Marker("Start Gate", systemImage: "flag.fill", coordinate: startCoord)
                        .tint(RunTheme.emerald)
                    MapCircle(center: startCoord, radius: corridorMeters)
                        .foregroundStyle(RunTheme.emerald.opacity(0.18))
                    MapCircle(center: startCoord, radius: corridorMeters)
                        .stroke(RunTheme.emerald, lineWidth: 1.5)
                }
                if let endCoord {
                    Marker("End Gate", systemImage: "flag.checkered", coordinate: endCoord)
                        .tint(RunTheme.coral)
                    MapCircle(center: endCoord, radius: corridorMeters)
                        .foregroundStyle(RunTheme.coral.opacity(0.18))
                    MapCircle(center: endCoord, radius: corridorMeters)
                        .stroke(RunTheme.coral, lineWidth: 1.5)
                }
                if let startCoord, let endCoord {
                    MapPolyline(coordinates: [startCoord, endCoord])
                        .stroke(RunTheme.amber.opacity(0.85), style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .onTapGesture { point in
                guard let coord = proxy.convert(point, from: .local) else { return }
                if startCoord == nil {
                    startCoord = coord
                } else {
                    endCoord = coord
                }
            }
        }
    }

    @ViewBuilder
    private var builderControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(instructionText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RunTheme.amber)
                Spacer()
                if startCoord != nil {
                    Button("Reset Pins") {
                        startCoord = nil
                        endCoord = nil
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            TextField("Section Name (e.g. River Sprint)", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Picker("Type", selection: $activityType) {
                    ForEach(ActivityType.gpsCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Text(RunFormatter.distance(meters: straightDistanceMeters, unit: settings.unitSystem))
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(canSave ? RunTheme.electricTeal : .secondary)
            }

            HStack {
                Text("Gate Radius")
                    .font(.caption)
                Slider(value: $corridorMeters, in: 20...60, step: 5)
                Text("\(Int(corridorMeters)) m")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private var instructionText: String {
        if startCoord == nil {
            return "Step 1: Tap the map to drop the Start gate"
        } else if endCoord == nil {
            return "Step 2: Tap the map to drop the End gate"
        } else if straightDistanceMeters < 20.0 {
            return "Place Start and End at least 20 m apart"
        } else {
            return "Gates set — single-user local matching"
        }
    }

    private func saveSection() {
        guard let startCoord, let endCoord, straightDistanceMeters >= 20.0 else { return }
        let bearing = GeoMath.bearingDegrees(
            lat1: startCoord.latitude,
            lon1: startCoord.longitude,
            lat2: endCoord.latitude,
            lon2: endCoord.longitude
        )
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = "\(activityType.displayName) Section (\(RunFormatter.distance(meters: straightDistanceMeters, unit: settings.unitSystem, decimals: 1)))"
        let section = SDSection(
            name: cleanName.isEmpty ? fallbackName : cleanName,
            activityTypeRaw: activityType.rawValue,
            startLatitude: startCoord.latitude,
            startLongitude: startCoord.longitude,
            endLatitude: endCoord.latitude,
            endLongitude: endCoord.longitude,
            expectedBearing: bearing,
            distanceMeters: straightDistanceMeters,
            corridorMeters: corridorMeters
        )
        modelContext.insert(section)
        try? modelContext.save()
        dismiss()
    }
}

private struct SectionActivityInput: Sendable {
    let id: UUID
    let title: String
    let activityType: ActivityType
    let trackFileName: String
}

struct SectionDetailView: View {
    @Environment(AppSettingsStore.self) private var settings

    let section: SDSection
    @Query(sort: \SDActivity.startDate, order: .reverse) private var allActivities: [SDActivity]

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var attempts: [SectionAttempt] = []
    @State private var isScanning = true

    private var sectionType: ActivityType {
        ActivityType(rawValue: section.activityTypeRaw) ?? .run
    }

    private var startCoord: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: section.startLatitude, longitude: section.startLongitude)
    }

    private var endCoord: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: section.endLatitude, longitude: section.endLongitude)
    }

    private var activityByID: [UUID: SDActivity] {
        Dictionary(uniqueKeysWithValues: allActivities.map { ($0.id, $0) })
    }

    var body: some View {
        List {
            Section {
                sectionMap
                    .listRowInsets(EdgeInsets())
            }

            if let best = attempts.first {
                Section("Personal Best") {
                    bestCard(best)
                }
            }

            Section("Your Attempts (\(attempts.count))") {
                if isScanning {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Scanning your saved \(sectionType.displayName.lowercased()) tracks...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if attempts.isEmpty {
                    Text("No past \(sectionType.displayName.lowercased()) activities matched both gates in direction.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(attempts.enumerated()), id: \.element.id) { index, attempt in
                        attemptRowLink(attempt: attempt, rank: index + 1)
                    }
                }
            }
        }
        .navigationTitle(section.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fitMapToGates()
        }
        .task(id: "\(section.id.uuidString)-\(allActivities.count)") {
            await scanActivities()
        }
    }

    @ViewBuilder
    private var sectionMap: some View {
        Map(position: $cameraPosition) {
            Marker("Start", systemImage: "flag.fill", coordinate: startCoord)
                .tint(RunTheme.emerald)
            MapCircle(center: startCoord, radius: section.corridorMeters)
                .foregroundStyle(RunTheme.emerald.opacity(0.18))
            MapCircle(center: startCoord, radius: section.corridorMeters)
                .stroke(RunTheme.emerald, lineWidth: 1.5)

            Marker("End", systemImage: "flag.checkered", coordinate: endCoord)
                .tint(RunTheme.coral)
            MapCircle(center: endCoord, radius: section.corridorMeters)
                .foregroundStyle(RunTheme.coral.opacity(0.18))
            MapCircle(center: endCoord, radius: section.corridorMeters)
                .stroke(RunTheme.coral, lineWidth: 1.5)

            MapPolyline(coordinates: [startCoord, endCoord])
                .stroke(RunTheme.amber.opacity(0.85), style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 220)
    }

    @ViewBuilder
    private func bestCard(_ best: SectionAttempt) -> some View {
        let metricText = sectionType.prefersSpeedOverPace
            ? RunFormatter.speed(metersPerSecond: best.speedMPS, unit: settings.unitSystem)
            : RunFormatter.pace(secondsPerMeter: best.paceSecondsPerMeter, unit: settings.unitSystem)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(best.activityTitle, systemImage: "trophy.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RunTheme.emerald)
                Spacer()
                Text(RunFormatter.duration(seconds: best.durationSeconds))
                    .font(.title3.weight(.black).monospacedDigit())
                    .foregroundStyle(RunTheme.electricTeal)
            }
            HStack {
                Text(metricText)
                Text("·")
                Text(RunFormatter.distance(meters: best.distanceMeters, unit: settings.unitSystem))
                Spacer()
                Text(best.date.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func attemptRowLink(attempt: SectionAttempt, rank: Int) -> some View {
        if let matched = activityByID[attempt.activityID] {
            NavigationLink(destination: ActivityDetailView(activity: matched)) {
                attemptRow(attempt, rank: rank)
            }
        } else {
            attemptRow(attempt, rank: rank)
        }
    }

    @ViewBuilder
    private func attemptRow(_ attempt: SectionAttempt, rank: Int) -> some View {
        let metricText = sectionType.prefersSpeedOverPace
            ? RunFormatter.speed(metersPerSecond: attempt.speedMPS, unit: settings.unitSystem)
            : RunFormatter.pace(secondsPerMeter: attempt.paceSecondsPerMeter, unit: settings.unitSystem)

        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(rank == 1 ? RunTheme.midnightSlate : .secondary)
                .frame(width: 28, height: 24)
                .background(rank == 1 ? RunTheme.emerald : Color.secondary.opacity(0.15))
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(attempt.activityTitle)
                    .font(.subheadline.weight(.semibold))
                Text("\(attempt.date.formatted(date: .abbreviated, time: .shortened)) · \(metricText)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(RunFormatter.duration(seconds: attempt.durationSeconds))
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(RunTheme.electricTeal)
        }
    }

    private func fitMapToGates() {
        let midLat = (section.startLatitude + section.endLatitude) * 0.5
        let midLon = (section.startLongitude + section.endLongitude) * 0.5
        let latDelta = max(0.004, abs(section.startLatitude - section.endLatitude) * 2.0)
        let lonDelta = max(0.004, abs(section.startLongitude - section.endLongitude) * 2.0)
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        )
    }

    private func scanActivities() async {
        isScanning = true
        let spec = SectionSpec(
            id: section.id,
            name: section.name,
            activityType: sectionType,
            startLatitude: section.startLatitude,
            startLongitude: section.startLongitude,
            endLatitude: section.endLatitude,
            endLongitude: section.endLongitude,
            expectedBearing: section.expectedBearing,
            distanceMeters: section.distanceMeters,
            corridorMeters: section.corridorMeters
        )
        let candidates = allActivities
            .filter { $0.activityType == sectionType }
            .map {
                SectionActivityInput(
                    id: $0.id,
                    title: $0.title,
                    activityType: $0.activityType,
                    trackFileName: $0.trackFileName
                )
            }

        let ranked = await Task.detached(priority: .userInitiated) { () -> [SectionAttempt] in
            var collected: [SectionAttempt] = []
            for item in candidates {
                guard let pts = try? TrackFileStore.shared.loadTrackPoints(fileName: item.trackFileName),
                      pts.count >= 2 else {
                    continue
                }
                let matches = SectionMatcher.findAttempts(
                    section: spec,
                    activityID: item.id,
                    activityTitle: item.title,
                    activityType: item.activityType,
                    points: pts
                )
                collected.append(contentsOf: matches)
            }
            return SectionMatcher.rankAttempts(collected)
        }.value

        attempts = ranked
        isScanning = false
    }
}
