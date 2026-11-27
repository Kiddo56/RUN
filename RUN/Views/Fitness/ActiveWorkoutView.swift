import SwiftData
import SwiftUI
import TrackerCore

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings
    @Environment(WorkoutSessionManager.self) private var workoutManager

    @Bindable var session: SDWorkoutSession

    @Query(sort: \SDWorkoutExerciseEntry.orderIndex) private var allEntries: [SDWorkoutExerciseEntry]
    @Query(sort: \SDSetEntry.orderIndex) private var allSets: [SDSetEntry]

    @State private var showingExercisePicker = false
    @State private var showingFinishSheet = false
    @State private var showingDiscardConfirm = false
    @State private var finishTitle = ""
    @State private var finishNotes = ""

    private var sessionEntries: [SDWorkoutExerciseEntry] {
        allEntries.filter { $0.workoutSessionID == session.id }
    }

    private func setsForEntry(_ entry: SDWorkoutExerciseEntry) -> [SDSetEntry] {
        allSets.filter { $0.workoutExerciseEntryID == entry.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if workoutManager.isRestTimerActive {
                    restTimerBanner
                }

                ScrollView {
                    VStack(spacing: 14) {
                        liveHeaderCard

                        if sessionEntries.isEmpty {
                            ContentUnavailableView(
                                "No Exercises Added",
                                systemImage: "dumbbell.fill",
                                description: Text("Tap Add Exercise below to start logging sets, weight, reps, and automatic rest timers.")
                            )
                            .padding(.top, 20)
                        } else {
                            ForEach(sessionEntries) { entry in
                                exerciseCard(entry)
                            }
                        }

                        Button {
                            showingExercisePicker = true
                        } label: {
                            Label("Add Exercise", systemImage: "plus.circle.fill")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(RunTheme.electricTeal.opacity(0.18))
                                .foregroundStyle(RunTheme.electricTeal)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Minimize") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDiscardConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Discard workout")

                    Button("Finish") {
                        finishTitle = session.title
                        finishNotes = session.notes
                        showingFinishSheet = true
                    }
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerSheet { selected in
                    workoutManager.addExercise(selected, toSession: session, modelContext: modelContext, settings: settings)
                }
            }
            .sheet(isPresented: $showingFinishSheet) {
                finishWorkoutSheet
            }
            .alert("Discard Workout?", isPresented: $showingDiscardConfirm) {
                Button("Discard", role: .destructive) {
                    workoutManager.discardActiveWorkout(modelContext: modelContext)
                    dismiss()
                }
                Button("Keep Lifting", role: .cancel) {}
            } message: {
                Text("This in-progress workout and all logged sets will be deleted.")
            }
        }
    }

    @ViewBuilder
    private var liveHeaderCard: some View {
        @Bindable var bindableSettings = settings
        let completedSets = allSets.filter { $0.workoutSessionID == session.id && $0.isCompleted }
        let workingVolume = completedSets.reduce(0.0) { acc, s in
            let type = SetType(rawValue: s.setTypeRaw) ?? .normal
            return acc + StrengthEngine.setVolumeKg(weightKg: s.weightKg, reps: s.reps, setType: type)
        }

        VStack(spacing: 10) {
            HStack(spacing: 10) {
                statPill(title: "DURATION", value: RunFormatter.duration(seconds: workoutManager.elapsedSeconds), color: RunTheme.electricTeal)
                statPill(title: "SETS DONE", value: "\(completedSets.count)", color: RunTheme.emerald)
                statPill(title: "VOLUME", value: RunFormatter.volume(kg: workingVolume, unit: settings.weightUnit), color: RunTheme.violet)
            }

            Toggle("Keep Screen Awake During Workout", isOn: $bindableSettings.keepScreenAwakeDuringWorkout)
                .font(.caption.weight(.semibold))
                .onChange(of: settings.keepScreenAwakeDuringWorkout) { _, enabled in
                    ScreenAwakeController.shared.setWorkoutAwake(enabled)
                }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func statPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var restTimerBanner: some View {
        let progress = workoutManager.restTotalSeconds > 0
            ? Double(workoutManager.restRemainingSeconds) / Double(workoutManager.restTotalSeconds)
            : 0

        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .foregroundStyle(RunTheme.electricTeal)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Rest: \(RunFormatter.duration(seconds: TimeInterval(workoutManager.restRemainingSeconds)))")
                        .font(.headline.weight(.bold).monospacedDigit())
                        .foregroundStyle(RunTheme.electricTeal)
                    if let exName = workoutManager.restExerciseName {
                        Text(exName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button("-15s") { workoutManager.adjustRestTimer(deltaSeconds: -15) }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.bordered)
                Button("+15s") { workoutManager.adjustRestTimer(deltaSeconds: 15) }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.bordered)
                Button("Skip") { workoutManager.skipRestTimer() }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.borderedProminent)
                    .tint(RunTheme.electricTeal)
                    .foregroundStyle(RunTheme.midnightSlate)
            }

            ProgressView(value: progress)
                .tint(RunTheme.electricTeal)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RunTheme.midnightSlate.opacity(0.92))
    }

    @ViewBuilder
    private func exerciseCard(_ entry: SDWorkoutExerciseEntry) -> some View {
        let sets = setsForEntry(entry)
        let prevSets = workoutManager.previousWorkingSets(
            forSlug: entry.exerciseSlug,
            excludingSessionID: session.id,
            modelContext: modelContext
        )
        let tracking = ExerciseTrackingType(rawValue: entry.trackingTypeRaw) ?? .weightReps

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.exerciseNameSnapshot)
                        .font(.headline)
                    if let prevBest = prevSets.first {
                        Text("Last: \(previousSummary(prevBest, tracking: tracking))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(RunTheme.electricTeal)
                    } else {
                        Text("No prior logged sets")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Menu {
                    ForEach([45, 60, 75, 90, 120, 150, 180], id: \.self) { sec in
                        Button("Rest \(sec)s") {
                            entry.restSeconds = sec
                            try? modelContext.save()
                        }
                    }
                    Divider()
                    Button("Remove Exercise", role: .destructive) {
                        removeExercise(entry)
                    }
                } label: {
                    Label("\(entry.restSeconds)s", systemImage: "timer")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(Capsule())
                }
            }

            ForEach(Array(sets.enumerated()), id: \.element.id) { idx, setEntry in
                ActiveSetRowView(
                    index: idx + 1,
                    setEntry: setEntry,
                    entry: entry,
                    trackingType: tracking,
                    weightUnit: settings.weightUnit,
                    onToggleComplete: {
                        workoutManager.toggleSetCompletion(setEntry, entry: entry, modelContext: modelContext, settings: settings)
                    },
                    onDelete: {
                        modelContext.delete(setEntry)
                        try? modelContext.save()
                    }
                )
            }

            Button {
                workoutManager.addSet(to: entry, modelContext: modelContext)
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func previousSummary(_ set: SDSetEntry, tracking: ExerciseTrackingType) -> String {
        switch tracking {
        case .weightReps:
            return "\(RunFormatter.weight(kg: set.weightKg, unit: settings.weightUnit)) × \(set.reps)"
        case .repsOnly:
            return "\(set.reps) reps"
        case .timeOnly:
            return "\(set.durationSeconds)s"
        }
    }

    private func removeExercise(_ entry: SDWorkoutExerciseEntry) {
        let sets = setsForEntry(entry)
        for s in sets { modelContext.delete(s) }
        modelContext.delete(entry)
        try? modelContext.save()
    }

    @ViewBuilder
    private var finishWorkoutSheet: some View {
        NavigationStack {
            Form {
                Section("Workout Summary") {
                    TextField("Workout Title", text: $finishTitle)
                    TextField("Notes (optional)", text: $finishNotes, axis: .vertical)
                        .lineLimit(3...6)
                    LabeledContent("Elapsed", value: RunFormatter.duration(seconds: workoutManager.elapsedSeconds))
                    LabeledContent("Exercises", value: "\(sessionEntries.count)")
                    let doneCount = allSets.filter { $0.workoutSessionID == session.id && $0.isCompleted }.count
                    LabeledContent("Completed Sets", value: "\(doneCount)")
                }
            }
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingFinishSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        workoutManager.finishWorkout(
                            session: session,
                            title: finishTitle,
                            notes: finishNotes,
                            modelContext: modelContext,
                            settings: settings
                        )
                        showingFinishSheet = false
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ActiveSetRowView: View {
    @Environment(\.modelContext) private var modelContext

    let index: Int
    @Bindable var setEntry: SDSetEntry
    let entry: SDWorkoutExerciseEntry
    let trackingType: ExerciseTrackingType
    let weightUnit: WeightUnit
    let onToggleComplete: () -> Void
    let onDelete: () -> Void

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var durationText = ""
    @State private var rpeText = ""
    @State private var didInitFields = false

    private var setType: SetType {
        SetType(rawValue: setEntry.setTypeRaw) ?? .normal
    }

    private var hasAnyPR: Bool {
        setEntry.isPRWeight || setEntry.isPREstimated1RM || setEntry.isPRReps || setEntry.isPRVolume
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Menu {
                    ForEach(SetType.allCases) { type in
                        Button(type.displayName) {
                            setEntry.setTypeRaw = type.rawValue
                            try? modelContext.save()
                        }
                    }
                    Divider()
                    Button("Delete Set", role: .destructive, action: onDelete)
                } label: {
                    Text(setType == .normal ? "\(index)" : setType.shortTag)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .frame(width: 28, height: 28)
                        .background(setTypeBadgeColor.opacity(0.2))
                        .foregroundStyle(setTypeBadgeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .accessibilityLabel("Set \(index), \(setType.displayName)")

                if trackingType == .weightReps {
                    TextField(weightUnit.symbol, text: $weightText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline.monospacedDigit())
                        .frame(maxWidth: .infinity)
                        .onChange(of: weightText) { _, newVal in
                            if let parsed = Double(newVal.replacingOccurrences(of: ",", with: ".")) {
                                setEntry.weightKg = weightUnit.toKilograms(max(0, parsed))
                                try? modelContext.save()
                            }
                        }
                }

                if trackingType == .timeOnly {
                    TextField("sec", text: $durationText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline.monospacedDigit())
                        .frame(maxWidth: .infinity)
                        .onChange(of: durationText) { _, newVal in
                            if let parsed = Int(newVal) {
                                setEntry.durationSeconds = max(0, parsed)
                                try? modelContext.save()
                            }
                        }
                } else {
                    TextField("reps", text: $repsText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline.monospacedDigit())
                        .frame(maxWidth: .infinity)
                        .onChange(of: repsText) { _, newVal in
                            if let parsed = Int(newVal) {
                                setEntry.reps = max(0, parsed)
                                try? modelContext.save()
                            }
                        }
                }

                TextField("RPE", text: $rpeText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospacedDigit())
                    .frame(width: 52)
                    .onChange(of: rpeText) { _, newVal in
                        if newVal.trimmingCharacters(in: .whitespaces).isEmpty {
                            setEntry.rpe = nil
                        } else if let parsed = Double(newVal.replacingOccurrences(of: ",", with: ".")) {
                            setEntry.rpe = min(10.0, max(1.0, parsed))
                        }
                        try? modelContext.save()
                    }

                Button(action: onToggleComplete) {
                    Image(systemName: setEntry.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(setEntry.isCompleted ? RunTheme.emerald : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(setEntry.isCompleted ? "Set \(index) completed" : "Mark set \(index) complete")
            }

            if hasAnyPR {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                    Text("PR!")
                    if setEntry.isPRWeight { Text("Weight") }
                    if setEntry.isPREstimated1RM { Text("Est. 1RM") }
                    if setEntry.isPRReps { Text("Reps") }
                    if setEntry.isPRVolume { Text("Volume") }
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(RunTheme.midnightSlate)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RunTheme.amber)
                .clipShape(Capsule())
                .padding(.leading, 34)
            }
        }
        .padding(.vertical, 3)
        .opacity(setEntry.isCompleted ? 0.92 : 1.0)
        .onAppear {
            guard !didInitFields else { return }
            didInitFields = true
            let displayW = weightUnit.fromKilograms(setEntry.weightKg)
            weightText = displayW > 0 ? String(format: displayW.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", displayW) : ""
            repsText = setEntry.reps > 0 ? "\(setEntry.reps)" : ""
            durationText = setEntry.durationSeconds > 0 ? "\(setEntry.durationSeconds)" : ""
            rpeText = setEntry.rpe.map { String(format: "%.1f", $0) } ?? ""
        }
    }

    private var setTypeBadgeColor: Color {
        switch setType {
        case .warmUp: return RunTheme.amber
        case .normal: return RunTheme.electricTeal
        case .drop: return RunTheme.violet
        case .failure: return RunTheme.coral
        }
    }
}
