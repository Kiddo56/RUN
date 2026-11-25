import MapKit
import SwiftData
import SwiftUI
import TrackerCore

struct EditActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var activity: SDActivity
    @Query(sort: \SDGear.name) private var gearItems: [SDGear]

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedType: ActivityType = .run
    @State private var selectedGearID: UUID? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Title & Notes") {
                    TextField("Activity Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Activity Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(ActivityType.allCases) { type in
                            Label(type.displayName, systemImage: type.symbolName)
                                .tag(type)
                        }
                    }
                }

                Section("Gear") {
                    if gearItems.isEmpty {
                        Text("Add shoes or bikes in Gear (Phase 3) to assign them here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Gear Used", selection: $selectedGearID) {
                            Text("None").tag(Optional<UUID>.none)
                            ForEach(gearItems) { gear in
                                Text(gear.name).tag(Optional(gear.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                title = activity.title
                notes = activity.notes
                selectedType = activity.activityType
                selectedGearID = activity.gearID
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !clean.isEmpty {
                            activity.title = clean
                        }
                        activity.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        activity.activityType = selectedType
                        activity.gearID = selectedGearID
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TrimActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @Bindable var activity: SDActivity
    let points: [TrackPoint]

    @State private var startDouble: Double = 0
    @State private var endDouble: Double = 1

    private var maxIndex: Int {
        max(1, points.count - 1)
    }

    private var clampedStartIndex: Int {
        let rawStart = max(0, min(maxIndex - 1, Int(startDouble.rounded())))
        let rawEnd = max(1, min(maxIndex, Int(endDouble.rounded())))
        return min(rawStart, rawEnd - 1)
    }

    private var clampedEndIndex: Int {
        let rawEnd = max(1, min(maxIndex, Int(endDouble.rounded())))
        return max(clampedStartIndex + 1, rawEnd)
    }

    private var previewResult: TrackEditResult? {
        TrackEditor.trim(
            points: points,
            startIndex: clampedStartIndex,
            endIndex: clampedEndIndex,
            activityType: activity.activityType,
            unitSystem: settings.unitSystem,
            userWeightKg: settings.userWeightKg,
            elevationHysteresisMeters: settings.elevationHysteresisMeters
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                trimMapPreview

                if let preview = previewResult {
                    HStack(spacing: 12) {
                        statChip(
                            title: "NEW DISTANCE",
                            value: RunFormatter.distance(meters: preview.summary.distanceMeters, unit: settings.unitSystem)
                        )
                        statChip(
                            title: "MOVING TIME",
                            value: RunFormatter.duration(seconds: preview.summary.movingTime)
                        )
                        statChip(
                            title: "POINTS",
                            value: "\(preview.points.count) / \(points.count)"
                        )
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trim Start (Point \(clampedStartIndex + 1))")
                            .font(.subheadline.weight(.semibold))
                        Slider(value: $startDouble, in: 0...Double(maxIndex))
                            .tint(RunTheme.emerald)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trim End (Point \(clampedEndIndex + 1))")
                            .font(.subheadline.weight(.semibold))
                        Slider(value: $endDouble, in: 0...Double(maxIndex))
                            .tint(RunTheme.coral)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Trim Route")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                startDouble = 0
                endDouble = Double(maxIndex)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyTrim()
                    }
                    .disabled(previewResult == nil)
                }
            }
        }
    }

    @ViewBuilder
    private var trimMapPreview: some View {
        let fullCoords = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let safeSlice: [TrackPoint] = (points.count >= 2 && clampedStartIndex < clampedEndIndex && clampedEndIndex < points.count)
            ? Array(points[clampedStartIndex...clampedEndIndex])
            : points
        let keptSlice = safeSlice.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        Map {
            if fullCoords.count >= 2 {
                MapPolyline(coordinates: fullCoords)
                    .stroke(Color.gray.opacity(0.45), lineWidth: 4)
            }
            if keptSlice.count >= 2 {
                MapPolyline(coordinates: keptSlice)
                    .stroke(RunTheme.electricTeal, lineWidth: 5)
            }
            if let first = keptSlice.first {
                Marker("Start", systemImage: "flag.fill", coordinate: first)
                    .tint(RunTheme.emerald)
            }
            if let last = keptSlice.last {
                Marker("End", systemImage: "flag.checkered", coordinate: last)
                    .tint(RunTheme.coral)
            }
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func applyTrim() {
        guard let result = previewResult else { return }
        do {
            try TrackFileStore.shared.saveTrackPoints(result.points, fileName: activity.trackFileName)
            applySummary(result.summary, to: activity)
            try? modelContext.save()
            DiagnosticsLogger.shared.log(.recording, "Trimmed activity \(activity.id) to \(result.points.count) pts")
            dismiss()
        } catch {
            DiagnosticsLogger.shared.log(.error, "Failed saving trimmed track: \(error.localizedDescription)")
        }
    }
}

struct MergeActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @Bindable var activity: SDActivity
    let primaryPoints: [TrackPoint]

    @Query(sort: \SDActivity.startDate, order: .reverse)
    private var allActivities: [SDActivity]

    @State private var selectedOtherID: UUID?
    @State private var errorMessage: String?

    private var candidates: [SDActivity] {
        allActivities.filter { $0.id != activity.id }
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(RunTheme.coral)
                    }
                }

                Section {
                    if candidates.isEmpty {
                        Text("No other activities available to merge.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(candidates) { candidate in
                            Button {
                                selectedOtherID = candidate.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(candidate.title)
                                            .font(.headline)
                                        Text("\(candidate.startDate.formatted(date: .abbreviated, time: .shortened)) · \(RunFormatter.distance(meters: candidate.distanceMeters, unit: settings.unitSystem))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedOtherID == candidate.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(RunTheme.electricTeal)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Select Second Activity")
                } footer: {
                    Text("Both GPS tracks will be ordered chronologically and combined into this activity without adding straight-line distance across time gaps.")
                }
            }
            .navigationTitle("Merge Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Merge") {
                        performMerge()
                    }
                    .disabled(selectedOtherID == nil)
                }
            }
        }
    }

    private func performMerge() {
        guard let otherID = selectedOtherID,
              let other = candidates.first(where: { $0.id == otherID }) else { return }

        do {
            let otherPoints = try TrackFileStore.shared.loadTrackPoints(fileName: other.trackFileName)
            guard let merged = TrackEditor.merge(
                first: primaryPoints,
                second: otherPoints,
                activityType: activity.activityType,
                unitSystem: settings.unitSystem,
                userWeightKg: settings.userWeightKg,
                elevationHysteresisMeters: settings.elevationHysteresisMeters
            ) else {
                errorMessage = "Selected activities do not contain enough GPS points to merge."
                return
            }

            try TrackFileStore.shared.saveTrackPoints(merged.points, fileName: activity.trackFileName)
            applySummary(merged.summary, to: activity)
            activity.source = "merged"

            TrackFileStore.shared.deleteTrackFile(fileName: other.trackFileName)
            modelContext.delete(other)
            try? modelContext.save()

            DiagnosticsLogger.shared.log(.recording, "Merged activity \(other.id) into \(activity.id) (\(merged.points.count) pts)")
            dismiss()
        } catch {
            errorMessage = "Could not load track data: \(error.localizedDescription)"
        }
    }
}

private func applySummary(_ summary: ActivityMetricsSummary, to activity: SDActivity) {
    activity.startDate = summary.startDate
    activity.endDate = summary.endDate
    activity.movingTime = summary.movingTime
    activity.elapsedTime = summary.elapsedTime
    activity.distanceMeters = summary.distanceMeters
    activity.elevationGainMeters = summary.elevationGainMeters
    activity.elevationLossMeters = summary.elevationLossMeters
    activity.averageHeartRate = summary.averageHeartRate
    activity.maxHeartRate = summary.maxHeartRate
    activity.effortScore = summary.effortScore
    activity.estimatedCalories = summary.estimatedCalories
    activity.pointCount = summary.pointCount
    activity.updateSplits(summary.splits)
    activity.updatePreviewCoordinates(summary.previewCoordinates)
}
