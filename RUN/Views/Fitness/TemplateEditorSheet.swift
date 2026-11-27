import SwiftData
import SwiftUI
import TrackerCore

private struct DraftTemplateItem: Identifiable {
    let id = UUID()
    let exerciseSlug: String
    let exerciseName: String
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetDurationSeconds: Int
    var defaultRestSeconds: Int
}

struct TemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let editingTemplate: SDWorkoutTemplate?

    @State private var name = ""
    @State private var notes = ""
    @State private var items: [DraftTemplateItem] = []
    @State private var showingExercisePicker = false
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine Info") {
                    TextField("Routine Name (e.g. Hypertrophy Upper)", text: $name)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Exercises (\(items.count))") {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.exerciseName)
                                .font(.subheadline.weight(.bold))

                            HStack(spacing: 12) {
                                Stepper("Sets: \(item.targetSets)", value: $item.targetSets, in: 1...10)
                                    .font(.caption)
                            }

                            if item.targetDurationSeconds > 0 {
                                Stepper("Hold: \(item.targetDurationSeconds)s", value: $item.targetDurationSeconds, in: 10...180, step: 5)
                                    .font(.caption)
                            } else {
                                HStack {
                                    Stepper("Min: \(item.targetRepsMin)", value: $item.targetRepsMin, in: 1...40)
                                        .font(.caption)
                                    Stepper("Max: \(item.targetRepsMax)", value: $item.targetRepsMax, in: max(1, item.targetRepsMin)...50)
                                        .font(.caption)
                                }
                            }

                            Stepper("Rest: \(item.defaultRestSeconds)s", value: $item.defaultRestSeconds, in: 15...240, step: 15)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                    }

                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(editingTemplate == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTemplate() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || items.isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerSheet { selected in
                    items.append(
                        DraftTemplateItem(
                            exerciseSlug: selected.id,
                            exerciseName: selected.name,
                            targetSets: 3,
                            targetRepsMin: selected.trackingType == .timeOnly ? 0 : 8,
                            targetRepsMax: selected.trackingType == .timeOnly ? 0 : 12,
                            targetDurationSeconds: selected.trackingType == .timeOnly ? 45 : 0,
                            defaultRestSeconds: 90
                        )
                    )
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                if let template = editingTemplate {
                    name = template.name
                    notes = template.notes
                    let existing = ((try? modelContext.fetch(FetchDescriptor<SDWorkoutTemplateItem>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? [])
                        .filter { $0.templateID == template.id }
                    items = existing.map {
                        DraftTemplateItem(
                            exerciseSlug: $0.exerciseSlug,
                            exerciseName: $0.exerciseNameSnapshot,
                            targetSets: $0.targetSets,
                            targetRepsMin: $0.targetRepsMin,
                            targetRepsMax: $0.targetRepsMax,
                            targetDurationSeconds: $0.targetDurationSeconds,
                            defaultRestSeconds: $0.defaultRestSeconds
                        )
                    }
                }
            }
        }
    }

    private func saveTemplate() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !items.isEmpty else { return }

        let template: SDWorkoutTemplate
        if let existing = editingTemplate {
            template = existing
            template.name = cleanName
            template.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            template.updatedAt = Date()
            let oldItems = ((try? modelContext.fetch(FetchDescriptor<SDWorkoutTemplateItem>())) ?? [])
                .filter { $0.templateID == existing.id }
            for old in oldItems {
                modelContext.delete(old)
            }
        } else {
            template = SDWorkoutTemplate(
                name: cleanName,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                isBuiltIn: false
            )
            modelContext.insert(template)
        }

        for (idx, draft) in items.enumerated() {
            let row = SDWorkoutTemplateItem(
                templateID: template.id,
                exerciseSlug: draft.exerciseSlug,
                exerciseNameSnapshot: draft.exerciseName,
                orderIndex: idx,
                targetSets: draft.targetSets,
                targetRepsMin: draft.targetRepsMin,
                targetRepsMax: max(draft.targetRepsMin, draft.targetRepsMax),
                targetDurationSeconds: draft.targetDurationSeconds,
                defaultRestSeconds: draft.defaultRestSeconds
            )
            modelContext.insert(row)
        }

        try? modelContext.save()
        dismiss()
    }
}
