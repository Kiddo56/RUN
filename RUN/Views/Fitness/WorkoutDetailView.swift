import SwiftData
import SwiftUI
import TrackerCore

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings
    @Environment(WorkoutSessionManager.self) private var workoutManager

    @Bindable var session: SDWorkoutSession

    @Query(sort: \SDWorkoutExerciseEntry.orderIndex) private var allEntries: [SDWorkoutExerciseEntry]
    @Query(sort: \SDSetEntry.orderIndex) private var allSets: [SDSetEntry]

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirm = false
    @State private var editTitle = ""
    @State private var editNotes = ""

    private var entries: [SDWorkoutExerciseEntry] {
        allEntries.filter { $0.workoutSessionID == session.id }
    }

    private func sets(for entry: SDWorkoutExerciseEntry) -> [SDSetEntry] {
        allSets.filter { $0.workoutExerciseEntryID == entry.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryHeader
                if !session.notes.isEmpty {
                    notesCard
                }
                ForEach(entries) { entry in
                    exerciseSummaryCard(entry)
                }
            }
            .padding(16)
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    editTitle = session.title
                    editNotes = session.notes
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit workout")

                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete workout")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            editWorkoutSheet
        }
        .alert("Delete Strength Workout?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                workoutManager.deleteWorkoutCascade(sessionID: session.id, modelContext: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This workout, its logged sets, and its timeline entry will be permanently deleted.")
        }
    }

    @ViewBuilder
    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Strength", systemImage: "dumbbell.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RunTheme.violet.opacity(0.18))
                    .foregroundStyle(RunTheme.violet)
                    .clipShape(Capsule())
                Spacer()
                Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricTile(title: "DURATION", value: RunFormatter.duration(seconds: session.durationSeconds), color: RunTheme.electricTeal)
                metricTile(title: "TOTAL VOLUME", value: RunFormatter.volume(kg: session.totalVolumeKg, unit: settings.weightUnit), color: RunTheme.emerald)
                metricTile(title: "EXERCISES", value: "\(entries.count)", color: .primary)
                metricTile(title: "SETS DONE", value: "\(session.completedSetCount)", color: RunTheme.violet)
            }
        }
    }

    @ViewBuilder
    private func metricTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NOTES")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(session.notes)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func exerciseSummaryCard(_ entry: SDWorkoutExerciseEntry) -> some View {
        let entrySets = sets(for: entry)
        let tracking = ExerciseTrackingType(rawValue: entry.trackingTypeRaw) ?? .weightReps

        VStack(alignment: .leading, spacing: 8) {
            Text(entry.exerciseNameSnapshot)
                .font(.headline)

            ForEach(Array(entrySets.enumerated()), id: \.element.id) { idx, s in
                let type = SetType(rawValue: s.setTypeRaw) ?? .normal
                let hasPR = s.isPRWeight || s.isPREstimated1RM || s.isPRReps || s.isPRVolume
                HStack(spacing: 8) {
                    Text(type == .normal ? "#\(idx + 1)" : type.shortTag)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 26, alignment: .leading)

                    Text(formatSet(s, tracking: tracking))
                        .font(.subheadline.weight(.semibold).monospacedDigit())

                    if let rpe = s.rpe {
                        Text("RPE \(String(format: "%.1f", rpe))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if hasPR {
                        Text("PR")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(RunTheme.amber)
                            .foregroundStyle(RunTheme.midnightSlate)
                            .clipShape(Capsule())
                    }

                    if s.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(RunTheme.emerald)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func formatSet(_ s: SDSetEntry, tracking: ExerciseTrackingType) -> String {
        switch tracking {
        case .weightReps:
            return "\(RunFormatter.weight(kg: s.weightKg, unit: settings.weightUnit)) × \(s.reps)"
        case .repsOnly:
            return "\(s.reps) reps"
        case .timeOnly:
            return "\(s.durationSeconds) s"
        }
    }

    @ViewBuilder
    private var editWorkoutSheet: some View {
        NavigationStack {
            Form {
                Section("Workout Info") {
                    TextField("Title", text: $editTitle)
                    TextField("Notes", text: $editNotes, axis: .vertical)
                        .lineLimit(3...6)
                }

                ForEach(entries) { entry in
                    Section(entry.exerciseNameSnapshot) {
                        ForEach(sets(for: entry)) { s in
                            EditablePastSetRow(
                                setEntry: s,
                                tracking: ExerciseTrackingType(rawValue: entry.trackingTypeRaw) ?? .weightReps,
                                weightUnit: settings.weightUnit
                            )
                        }
                    }
                }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingEditSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyEdits()
                        showingEditSheet = false
                    }
                }
            }
        }
    }

    private func applyEdits() {
        let cleanTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTitle.isEmpty {
            session.title = cleanTitle
        }
        session.notes = editNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        let sessionSets = allSets.filter { $0.workoutSessionID == session.id && $0.isCompleted }
        let vol = sessionSets.reduce(0.0) { acc, s in
            let type = SetType(rawValue: s.setTypeRaw) ?? .normal
            return acc + StrengthEngine.setVolumeKg(weightKg: s.weightKg, reps: s.reps, setType: type)
        }
        session.totalVolumeKg = vol
        session.completedSetCount = sessionSets.count

        if let linkedID = session.linkedActivityID {
            let acts = (try? modelContext.fetch(FetchDescriptor<SDActivity>())) ?? []
            if let act = acts.first(where: { $0.id == linkedID }) {
                act.title = session.title
                act.notes = session.notes
            }
        }
        try? modelContext.save()
    }
}

private struct EditablePastSetRow: View {
    @Bindable var setEntry: SDSetEntry
    let tracking: ExerciseTrackingType
    let weightUnit: WeightUnit

    @State private var weightStr = ""
    @State private var repsStr = ""
    @State private var durStr = ""
    @State private var loaded = false

    var body: some View {
        HStack(spacing: 10) {
            if tracking == .weightReps {
                TextField(weightUnit.symbol, text: $weightStr)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: weightStr) { _, v in
                        if let parsed = Double(v.replacingOccurrences(of: ",", with: ".")) {
                            setEntry.weightKg = weightUnit.toKilograms(max(0, parsed))
                        }
                    }
            }
            if tracking == .timeOnly {
                TextField("sec", text: $durStr)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: durStr) { _, v in
                        if let parsed = Int(v) { setEntry.durationSeconds = max(0, parsed) }
                    }
            } else {
                TextField("reps", text: $repsStr)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: repsStr) { _, v in
                        if let parsed = Int(v) { setEntry.reps = max(0, parsed) }
                    }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let w = weightUnit.fromKilograms(setEntry.weightKg)
            weightStr = w > 0 ? String(format: "%.1f", w) : ""
            repsStr = setEntry.reps > 0 ? "\(setEntry.reps)" : ""
            durStr = setEntry.durationSeconds > 0 ? "\(setEntry.durationSeconds)" : ""
        }
    }
}
