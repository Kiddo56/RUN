import SwiftData
import SwiftUI
import TrackerCore

private enum FitnessSectionTab: String, CaseIterable, Identifiable {
    case workouts = "Workouts"
    case exercises = "Exercises"
    case progress = "Progress"

    var id: String { rawValue }
}

struct FitnessHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings
    @Environment(WorkoutSessionManager.self) private var workoutManager

    @Query(sort: \SDWorkoutSession.startDate, order: .reverse) private var sessions: [SDWorkoutSession]
    @Query(sort: \SDWorkoutTemplate.createdAt) private var templates: [SDWorkoutTemplate]
    @Query private var templateItems: [SDWorkoutTemplateItem]

    @State private var selectedSection: FitnessSectionTab = .workouts
    @State private var showingNewTemplateSheet = false
    @State private var editingTemplate: SDWorkoutTemplate?
    @State private var scalingTemplate: SDWorkoutTemplate?
    @State private var selectedScaleFactor: Double = 1.0

    private var activeSession: SDWorkoutSession? {
        guard let id = workoutManager.activeSessionID else { return nil }
        return sessions.first(where: { $0.id == id })
    }

    private var completedSessions: [SDWorkoutSession] {
        sessions.filter(\.isCompleted)
    }

    var body: some View {
        @Bindable var bindableManager = workoutManager

        NavigationStack {
            VStack(spacing: 0) {
                if workoutManager.pendingRecoverySessionID != nil {
                    recoveryBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                if let active = activeSession, !workoutManager.isPresentingActiveWorkout {
                    activeWorkoutMiniBar(active)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                Picker("Fitness Section", selection: $selectedSection) {
                    ForEach(FitnessSectionTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                switch selectedSection {
                case .workouts:
                    workoutsContent
                case .exercises:
                    ExerciseLibraryView()
                case .progress:
                    FitnessProgressView()
                }
            }
            .navigationTitle("Fitness")
            .fullScreenCover(isPresented: $bindableManager.isPresentingActiveWorkout) {
                if let active = activeSession {
                    ActiveWorkoutView(session: active)
                }
            }
            .sheet(isPresented: $showingNewTemplateSheet) {
                TemplateEditorSheet(editingTemplate: nil)
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorSheet(editingTemplate: template)
            }
            .sheet(item: $scalingTemplate) { template in
                startTemplateScaleSheet(template)
            }
        }
    }

    @ViewBuilder
    private var recoveryBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundStyle(RunTheme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Unfinished Workout Found")
                    .font(.caption.weight(.bold))
                Text("Resume your autosaved strength session or discard it.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Resume") {
                workoutManager.resumePendingWorkout(modelContext: modelContext, settings: settings)
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(RunTheme.electricTeal)
            .foregroundStyle(RunTheme.midnightSlate)

            Button("Discard", role: .destructive) {
                workoutManager.discardPendingWorkout(modelContext: modelContext)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(12)
        .background(RunTheme.amber.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func activeWorkoutMiniBar(_ session: SDWorkoutSession) -> some View {
        Button {
            workoutManager.isPresentingActiveWorkout = true
        } label: {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(RunTheme.midnightSlate)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Active: \(session.title)")
                        .font(.caption.weight(.bold))
                    Text(RunFormatter.duration(seconds: workoutManager.elapsedSeconds))
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(RunTheme.midnightSlate)
                Spacer()
                Text("Open")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RunTheme.midnightSlate)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RunTheme.electricTeal)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var workoutsContent: some View {
        List {
            Section {
                Button {
                    _ = workoutManager.startEmptyWorkout(modelContext: modelContext, settings: settings)
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(RunTheme.electricTeal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Empty Workout")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Add exercises on the fly with autosave and rest timer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .disabled(workoutManager.activeSessionID != nil)
            }

            Section {
                ForEach(templates) { template in
                    templateRow(template)
                }

                Button {
                    showingNewTemplateSheet = true
                } label: {
                    Label("Create New Routine Template", systemImage: "plus.circle")
                }
            } header: {
                Text("Routine Templates (\(templates.count))")
            }

            Section("Recent Strength Workouts") {
                if completedSessions.isEmpty {
                    Text("Completed workouts appear here and in your main History timeline & calendar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(completedSessions.prefix(15)) { session in
                        NavigationLink(destination: WorkoutDetailView(session: session)) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(session.title)
                                        .font(.subheadline.weight(.bold))
                                    Spacer()
                                    Text(RunFormatter.duration(seconds: session.durationSeconds))
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(RunTheme.electricTeal)
                                }
                                Text("\(session.startDate.formatted(date: .abbreviated, time: .shortened)) · \(session.exerciseCount) ex · \(session.completedSetCount) sets · \(RunFormatter.volume(kg: session.totalVolumeKg, unit: settings.weightUnit))")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete(perform: deleteCompletedSessions)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func templateRow(_ template: SDWorkoutTemplate) -> some View {
        let count = templateItems.filter { $0.templateID == template.id }.count
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.subheadline.weight(.bold))
                    if template.isBuiltIn {
                        Text("Built-In")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RunTheme.electricTeal.opacity(0.16))
                            .foregroundStyle(RunTheme.electricTeal)
                            .clipShape(Capsule())
                    }
                }
                Text("\(count) exercise\(count == 1 ? "" : "s")\(template.notes.isEmpty ? "" : " · \(template.notes)")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Start") {
                selectedScaleFactor = 1.0
                scalingTemplate = template
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(RunTheme.electricTeal)
            .foregroundStyle(RunTheme.midnightSlate)
            .disabled(workoutManager.activeSessionID != nil)
        }
        .contextMenu {
            Button {
                editingTemplate = template
            } label: {
                Label("Edit Routine", systemImage: "pencil")
            }

            Button {
                duplicateTemplate(template)
            } label: {
                Label("Duplicate Routine", systemImage: "doc.on.doc")
            }

            if !template.isBuiltIn {
                Button(role: .destructive) {
                    deleteTemplate(template)
                } label: {
                    Label("Delete Routine", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func startTemplateScaleSheet(_ template: SDWorkoutTemplate) -> some View {
        let items = templateItems
            .filter { $0.templateID == template.id }
            .sorted { $0.orderIndex < $1.orderIndex }

        NavigationStack {
            Form {
                Section("Intensity / Volume Scaling") {
                    Picker("Volume Scale", selection: $selectedScaleFactor) {
                        Text("Deload (75%)").tag(0.75)
                        Text("Standard (100%)").tag(1.0)
                        Text("Push (125%)").tag(1.25)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Planned Exercises (\(items.count))") {
                    ForEach(items) { item in
                        let scaled = StrengthEngine.scaleTemplateTarget(
                            targetSets: item.targetSets,
                            targetRepsMin: item.targetRepsMin,
                            targetRepsMax: item.targetRepsMax,
                            targetDurationSeconds: item.targetDurationSeconds,
                            factor: selectedScaleFactor
                        )
                        HStack {
                            Text(item.exerciseNameSnapshot)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if scaled.targetDurationSeconds > 0 {
                                Text("\(scaled.targetSets) × \(scaled.targetDurationSeconds)s")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(scaled.targetSets) × \(scaled.targetRepsMin)–\(scaled.targetRepsMax)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { scalingTemplate = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Workout") {
                        let chosen = template
                        let factor = selectedScaleFactor
                        scalingTemplate = nil
                        _ = workoutManager.startWorkout(
                            from: chosen,
                            scaleFactor: factor,
                            modelContext: modelContext,
                            settings: settings
                        )
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func duplicateTemplate(_ source: SDWorkoutTemplate) {
        let copy = SDWorkoutTemplate(
            name: "\(source.name) Copy",
            notes: source.notes,
            isBuiltIn: false
        )
        modelContext.insert(copy)
        let sourceItems = templateItems
            .filter { $0.templateID == source.id }
            .sorted { $0.orderIndex < $1.orderIndex }
        for item in sourceItems {
            modelContext.insert(
                SDWorkoutTemplateItem(
                    templateID: copy.id,
                    exerciseSlug: item.exerciseSlug,
                    exerciseNameSnapshot: item.exerciseNameSnapshot,
                    orderIndex: item.orderIndex,
                    targetSets: item.targetSets,
                    targetRepsMin: item.targetRepsMin,
                    targetRepsMax: item.targetRepsMax,
                    targetDurationSeconds: item.targetDurationSeconds,
                    defaultRestSeconds: item.defaultRestSeconds,
                    notes: item.notes
                )
            )
        }
        try? modelContext.save()
    }

    private func deleteTemplate(_ template: SDWorkoutTemplate) {
        for item in templateItems where item.templateID == template.id {
            modelContext.delete(item)
        }
        modelContext.delete(template)
        try? modelContext.save()
    }

    private func deleteCompletedSessions(at offsets: IndexSet) {
        let list = Array(completedSessions.prefix(15))
        for idx in offsets {
            workoutManager.deleteWorkoutCascade(sessionID: list[idx].id, modelContext: modelContext)
        }
    }
}
