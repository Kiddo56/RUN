import SwiftData
import SwiftUI
import TrackerCore

private enum HistoryDisplayMode: String, CaseIterable, Identifiable {
    case timeline = "Timeline"
    case calendar = "Calendar"

    var id: String { rawValue }
}

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @Query(sort: \SDActivity.startDate, order: .reverse)
    private var activities: [SDActivity]
    @Query
    private var workoutSessions: [SDWorkoutSession]

    @State private var displayMode: HistoryDisplayMode = .timeline
    @State private var selectedTypeFilter: ActivityType? = nil
    @State private var searchText: String = ""
    @State private var showingBackupSheet = false

    private var filteredActivities: [SDActivity] {
        activities.filter { activity in
            if let selectedTypeFilter, activity.activityType != selectedTypeFilter {
                return false
            }
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !q.isEmpty {
                return activity.title.lowercased().contains(q)
                    || activity.notes.lowercased().contains(q)
                    || activity.activityType.displayName.lowercased().contains(q)
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if settings.needsBackupReminder(activityCount: activities.count) {
                    BackupReminderBanner(daysSinceBackup: settings.daysSinceLastBackup()) {
                        showingBackupSheet = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                Picker("History View", selection: $displayMode) {
                    ForEach(HistoryDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if displayMode == .timeline {
                    typeFilterStrip
                    timelineContent
                } else {
                    ActivityCalendarView(
                        activities: filteredActivities,
                        workoutSessions: workoutSessions,
                        unitSystem: settings.unitSystem,
                        weightUnit: settings.weightUnit
                    )
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search activities")
            .sheet(isPresented: $showingBackupSheet) {
                NavigationStack {
                    DataAndBackupView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingBackupSheet = false }
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var typeFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(title: "All", type: nil)
                ForEach(ActivityType.allCases) { type in
                    filterPill(title: type.displayName, type: type)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func filterPill(title: String, type: ActivityType?) -> some View {
        let isSelected = selectedTypeFilter == type
        Button(title) {
            selectedTypeFilter = type
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? RunTheme.electricTeal : Color.secondary.opacity(0.15))
        .foregroundStyle(isSelected ? RunTheme.midnightSlate : Color.primary)
        .clipShape(Capsule())
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var timelineContent: some View {
        if filteredActivities.isEmpty {
            ContentUnavailableView(
                activities.isEmpty ? "No Activities Yet" : "No Matching Activities",
                systemImage: "figure.run",
                description: Text(
                    activities.isEmpty
                        ? "Recorded runs, rides, walks, and hikes will appear here."
                        : "Try clearing your search or filter selection."
                )
            )
        } else {
            let sessionByLinkedID = Dictionary(
                uniqueKeysWithValues: workoutSessions.compactMap { s in
                    s.linkedActivityID.map { ($0, s) }
                }
            )
            List {
                ForEach(filteredActivities) { activity in
                    if activity.activityType == .strength, let session = sessionByLinkedID[activity.id] {
                        NavigationLink(destination: WorkoutDetailView(session: session)) {
                            StrengthActivityRowCard(activity: activity, session: session, weightUnit: settings.weightUnit)
                        }
                    } else {
                        NavigationLink(destination: ActivityDetailView(activity: activity)) {
                            ActivityRowCard(activity: activity, unitSystem: settings.unitSystem)
                        }
                    }
                }
                .onDelete(perform: deleteActivities)
            }
            .listStyle(.insetGrouped)
        }
    }

    private func deleteActivities(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { filteredActivities[$0] }
        for activity in itemsToDelete {
            if activity.activityType == .strength,
               let linked = workoutSessions.first(where: { $0.linkedActivityID == activity.id }) {
                let targetID = linked.id
                modelContext.delete(linked)
                for entry in ((try? modelContext.fetch(FetchDescriptor<SDWorkoutExerciseEntry>())) ?? []) where entry.workoutSessionID == targetID {
                    modelContext.delete(entry)
                }
                for s in ((try? modelContext.fetch(FetchDescriptor<SDSetEntry>())) ?? []) where s.workoutSessionID == targetID {
                    modelContext.delete(s)
                }
            }
            if !activity.trackFileName.isEmpty {
                TrackFileStore.shared.deleteTrackFile(fileName: activity.trackFileName)
            }
            modelContext.delete(activity)
        }
        try? modelContext.save()
    }
}

struct StrengthActivityRowCard: View {
    let activity: SDActivity
    let session: SDWorkoutSession
    let weightUnit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(RunTheme.midnightSlate)
                Image(systemName: "dumbbell.fill")
                    .font(.title3)
                    .foregroundStyle(RunTheme.violet)
            }
            .frame(width: 56, height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RunTheme.hudBorder.opacity(0.6), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text("Strength")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RunTheme.violet.opacity(0.18))
                        .foregroundStyle(RunTheme.violet)
                        .clipShape(Capsule())
                }

                Text(activity.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Text(RunFormatter.duration(seconds: session.durationSeconds))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                    Text("\(session.exerciseCount) ex · \(session.completedSetCount) sets")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(RunFormatter.volume(kg: session.totalVolumeKg, unit: weightUnit))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(RunTheme.emerald)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ActivityRowCard: View {
    let activity: SDActivity
    let unitSystem: UnitSystem

    var body: some View {
        let coords = activity.decodedPreviewCoordinates()

        HStack(spacing: 12) {
            RouteThumbnailBadge(
                coordinates: coords,
                symbolName: activity.activityType.symbolName
            )
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(activity.activityType.displayName)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RunTheme.electricTeal.opacity(0.15))
                        .foregroundStyle(RunTheme.electricTeal)
                        .clipShape(Capsule())
                }

                Text(activity.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Text(RunFormatter.distance(meters: activity.distanceMeters, unit: unitSystem))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                    Text(RunFormatter.duration(seconds: activity.movingTime))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if activity.activityType.prefersSpeedOverPace {
                        Text(RunFormatter.speed(metersPerSecond: activity.averageSpeedMPS, unit: unitSystem))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text(RunFormatter.pace(secondsPerMeter: activity.averagePaceSecondsPerMeter, unit: unitSystem))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RouteThumbnailBadge: View {
    let coordinates: [PreviewCoordinate]
    let symbolName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(RunTheme.midnightSlate)

            if coordinates.count >= 2 {
                Canvas { context, size in
                    let lats = coordinates.map(\.latitude)
                    let lons = coordinates.map(\.longitude)
                    guard let minLat = lats.min(),
                          let maxLat = lats.max(),
                          let minLon = lons.min(),
                          let maxLon = lons.max() else { return }

                    let inset: CGFloat = 8
                    let spanLon = max(maxLon - minLon, 1e-6)
                    let spanLat = max(maxLat - minLat, 1e-6)
                    let drawW = max(1, size.width - inset * 2)
                    let drawH = max(1, size.height - inset * 2)
                    let scale = min(drawW / spanLon, drawH / spanLat)
                    let offsetX = (size.width - spanLon * scale) * 0.5
                    let offsetY = (size.height - spanLat * scale) * 0.5

                    var path = Path()
                    for (idx, pt) in coordinates.enumerated() {
                        let x = offsetX + CGFloat(pt.longitude - minLon) * scale
                        let y = size.height - (offsetY + CGFloat(pt.latitude - minLat) * scale)
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    context.stroke(path, with: .color(RunTheme.electricTeal), lineWidth: 2.2)
                }
            } else {
                Image(systemName: symbolName)
                    .font(.title3)
                    .foregroundStyle(RunTheme.electricTeal)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RunTheme.hudBorder.opacity(0.6), lineWidth: 1)
        )
    }
}
