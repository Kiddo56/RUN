import SwiftData
import SwiftUI
import TrackerCore

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @Query(sort: \SDCustomExercise.name) private var customExercises: [SDCustomExercise]
    @Query private var preferences: [SDExercisePreference]

    @State private var searchText = ""
    @State private var selectedGroup: MuscleGroup? = nil
    @State private var selectedEquipment: ExerciseEquipment? = nil
    @State private var selectedDifficulty: ExerciseDifficulty? = nil
    @State private var favoritesOnly = false
    @State private var showingAddCustom = false

    private var favoriteSlugs: Set<String> {
        Set(preferences.filter(\.isFavorite).map(\.exerciseSlug))
    }

    private var filteredExercises: [CatalogExercise] {
        let all = ExerciseCatalogService.shared.allExercises(custom: customExercises)
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return all.filter { ex in
            if let selectedGroup, ex.muscleGroup != selectedGroup { return false }
            if let selectedEquipment, !ex.equipment.contains(selectedEquipment) { return false }
            if let selectedDifficulty, ex.difficulty != selectedDifficulty { return false }
            if favoritesOnly && !favoriteSlugs.contains(ex.id) { return false }
            if !q.isEmpty {
                let nameMatch = ex.name.lowercased().contains(q)
                let aliasMatch = ex.aliases.contains { $0.lowercased().contains(q) }
                let muscleMatch = ex.primaryMuscles.contains { $0.lowercased().contains(q) }
                return nameMatch || aliasMatch || muscleMatch
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterControls

            List {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(RunTheme.electricTeal)
                        Text("General fitness information, not medical advice. Stop immediately if any movement causes sharp pain.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Exercises (\(filteredExercises.count))") {
                    if filteredExercises.isEmpty {
                        ContentUnavailableView(
                            "No Matching Exercises",
                            systemImage: "dumbbell",
                            description: Text("Try clearing a filter or create a custom exercise.")
                        )
                    } else {
                        ForEach(filteredExercises) { exercise in
                            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                                exerciseRow(exercise)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .searchable(text: $searchText, prompt: "Search 130+ exercises or muscles")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddCustom = true
                } label: {
                    Label("Add Custom Exercise", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCustom) {
            AddCustomExerciseSheet()
        }
    }

    @ViewBuilder
    private var filterControls: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    groupPill(title: "All", group: nil)
                    ForEach(MuscleGroup.allCases) { group in
                        groupPill(title: group.shortName, group: group)
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 8) {
                Menu {
                    Button("All Equipment") { selectedEquipment = nil }
                    ForEach(ExerciseEquipment.allCases) { eq in
                        Button(eq.displayName) { selectedEquipment = eq }
                    }
                } label: {
                    filterMenuChip(
                        label: selectedEquipment?.displayName ?? "Equipment",
                        active: selectedEquipment != nil
                    )
                }

                Menu {
                    Button("All Levels") { selectedDifficulty = nil }
                    ForEach(ExerciseDifficulty.allCases) { diff in
                        Button(diff.displayName) { selectedDifficulty = diff }
                    }
                } label: {
                    filterMenuChip(
                        label: selectedDifficulty?.displayName ?? "Difficulty",
                        active: selectedDifficulty != nil
                    )
                }

                Button {
                    favoritesOnly.toggle()
                } label: {
                    Label("Favorites", systemImage: favoritesOnly ? "star.fill" : "star")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(favoritesOnly ? RunTheme.amber.opacity(0.22) : Color.secondary.opacity(0.14))
                        .foregroundStyle(favoritesOnly ? RunTheme.amber : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func groupPill(title: String, group: MuscleGroup?) -> some View {
        let active = selectedGroup == group
        Button(title) {
            selectedGroup = group
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(active ? RunTheme.electricTeal : Color.secondary.opacity(0.15))
        .foregroundStyle(active ? RunTheme.midnightSlate : .primary)
        .clipShape(Capsule())
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func filterMenuChip(label: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Text(label)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(active ? RunTheme.electricTeal.opacity(0.2) : Color.secondary.opacity(0.14))
        .foregroundStyle(active ? RunTheme.electricTeal : .primary)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func exerciseRow(_ exercise: CatalogExercise) -> some View {
        let isFav = favoriteSlugs.contains(exercise.id)
        HStack(spacing: 12) {
            Image(systemName: exercise.muscleGroup.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(RunTheme.electricTeal)
                .frame(width: 34, height: 34)
                .background(RunTheme.electricTeal.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                    if exercise.isCustom {
                        Text("Custom")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RunTheme.violet.opacity(0.18))
                            .foregroundStyle(RunTheme.violet)
                            .clipShape(Capsule())
                    }
                }
                Text("\(exercise.muscleGroup.shortName) · \(exercise.equipment.map(\.displayName).joined(separator: ", ")) · \(exercise.difficulty.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isFav {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(RunTheme.amber)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    let exercise: CatalogExercise

    @Query private var preferences: [SDExercisePreference]
    @State private var notesDraft = ""
    @State private var restSecondsDraft = 90
    @State private var isFavoriteDraft = false
    @State private var didLoadPreference = false

    private var existingPreference: SDExercisePreference? {
        preferences.first(where: { $0.exerciseSlug == exercise.id })
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: exercise.muscleGroup.symbolName)
                        .font(.title2)
                        .foregroundStyle(RunTheme.electricTeal)
                        .frame(width: 48, height: 48)
                        .background(RunTheme.electricTeal.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.muscleGroup.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RunTheme.electricTeal)
                        Text("\(exercise.mechanic.displayName) · \(exercise.difficulty.displayName) · \(exercise.trackingType.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Primary", value: exercise.primaryMuscles.joined(separator: ", "))
                if !exercise.secondaryMuscles.isEmpty {
                    LabeledContent("Secondary", value: exercise.secondaryMuscles.joined(separator: ", "))
                }
                LabeledContent("Equipment", value: exercise.equipment.map(\.displayName).joined(separator: ", "))
                if !exercise.aliases.isEmpty {
                    LabeledContent("Also Known As", value: exercise.aliases.joined(separator: ", "))
                }
            }

            Section("How to Perform") {
                ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(RunTheme.midnightSlate)
                            .frame(width: 22, height: 22)
                            .background(RunTheme.electricTeal)
                            .clipShape(Circle())
                        Text(step)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            }

            if !exercise.tips.isEmpty || !exercise.commonMistakes.isEmpty {
                Section("Form Cues") {
                    if !exercise.tips.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Coaching Tip", systemImage: "checkmark.seal.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RunTheme.emerald)
                            Text(exercise.tips)
                                .font(.subheadline)
                        }
                    }
                    if !exercise.commonMistakes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Common Mistake", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RunTheme.amber)
                            Text(exercise.commonMistakes)
                                .font(.subheadline)
                        }
                    }
                }
            }

            Section("Personal Settings & Notes") {
                Toggle("Favorite Exercise", isOn: $isFavoriteDraft)
                    .onChange(of: isFavoriteDraft) { _, _ in savePreference() }

                Stepper(value: $restSecondsDraft, in: 15...300, step: 15) {
                    LabeledContent("Default Rest Timer", value: "\(restSecondsDraft) s")
                }
                .onChange(of: restSecondsDraft) { _, _ in savePreference() }

                TextField("Personal setup cues, seat height, grip width…", text: $notesDraft, axis: .vertical)
                    .lineLimit(3...6)
                    .onChange(of: notesDraft) { _, _ in savePreference() }
            }

            Section {
                Text("General fitness information, not medical advice. Stop immediately if an exercise causes pain.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didLoadPreference else { return }
            didLoadPreference = true
            if let pref = existingPreference {
                isFavoriteDraft = pref.isFavorite
                notesDraft = pref.personalNotes
                restSecondsDraft = pref.defaultRestSeconds > 0 ? pref.defaultRestSeconds : settings.defaultRestSeconds
            } else {
                isFavoriteDraft = false
                notesDraft = ""
                restSecondsDraft = settings.defaultRestSeconds
            }
        }
    }

    private func savePreference() {
        if let pref = existingPreference {
            pref.isFavorite = isFavoriteDraft
            pref.personalNotes = notesDraft
            pref.defaultRestSeconds = restSecondsDraft
            pref.updatedAt = Date()
        } else {
            let pref = SDExercisePreference(
                exerciseSlug: exercise.id,
                isFavorite: isFavoriteDraft,
                personalNotes: notesDraft,
                defaultRestSeconds: restSecondsDraft
            )
            modelContext.insert(pref)
        }
        try? modelContext.save()
    }
}

struct AddCustomExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .legs
    @State private var equipment: ExerciseEquipment = .dumbbell
    @State private var mechanic: ExerciseMechanic = .compound
    @State private var difficulty: ExerciseDifficulty = .intermediate
    @State private var trackingType: ExerciseTrackingType = .weightReps
    @State private var primaryMuscles = ""
    @State private var instructionsText = ""
    @State private var tips = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise Name", text: $name)
                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(MuscleGroup.allCases) { group in
                            Text(group.displayName).tag(group)
                        }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(ExerciseEquipment.allCases) { eq in
                            Text(eq.displayName).tag(eq)
                        }
                    }
                    Picker("Mechanic", selection: $mechanic) {
                        ForEach(ExerciseMechanic.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(ExerciseDifficulty.allCases) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    Picker("Tracking", selection: $trackingType) {
                        ForEach(ExerciseTrackingType.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                }

                Section("Guidance (Optional)") {
                    TextField("Primary muscles (comma separated)", text: $primaryMuscles)
                    TextField("Instructions (one step per line)", text: $instructionsText, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Tips", text: $tips, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCustom() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveCustom() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let slugBase = cleanName.lowercased().replacingOccurrences(of: " ", with: "-")
        let slug = "custom-\(slugBase)-\(UUID().uuidString.prefix(6).lowercased())"
        let item = SDCustomExercise(
            slug: slug,
            name: cleanName,
            muscleGroupRaw: muscleGroup.rawValue,
            primaryMusclesCSV: primaryMuscles.isEmpty ? muscleGroup.shortName : primaryMuscles,
            equipmentCSV: equipment.rawValue,
            mechanicRaw: mechanic.rawValue,
            difficultyRaw: difficulty.rawValue,
            trackingTypeRaw: trackingType.rawValue,
            instructionsText: instructionsText,
            tips: tips
        )
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SDCustomExercise.name) private var customExercises: [SDCustomExercise]
    @Query private var preferences: [SDExercisePreference]

    let onSelect: (CatalogExercise) -> Void

    @State private var searchText = ""
    @State private var selectedGroup: MuscleGroup? = nil

    private var favoriteSlugs: Set<String> {
        Set(preferences.filter(\.isFavorite).map(\.exerciseSlug))
    }

    private var matching: [CatalogExercise] {
        let all = ExerciseCatalogService.shared.allExercises(custom: customExercises)
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = all.filter { ex in
            if let selectedGroup, ex.muscleGroup != selectedGroup { return false }
            if !q.isEmpty {
                return ex.name.lowercased().contains(q)
                    || ex.aliases.contains { $0.lowercased().contains(q) }
                    || ex.muscleGroup.displayName.lowercased().contains(q)
            }
            return true
        }
        return filtered.sorted { lhs, rhs in
            let lFav = favoriteSlugs.contains(lhs.id)
            let rFav = favoriteSlugs.contains(rhs.id)
            if lFav != rFav { return lFav }
            return lhs.name < rhs.name
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("All") { selectedGroup = nil }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedGroup == nil ? RunTheme.electricTeal : Color.secondary.opacity(0.15))
                            .foregroundStyle(selectedGroup == nil ? RunTheme.midnightSlate : .primary)
                            .clipShape(Capsule())
                        ForEach(MuscleGroup.allCases) { group in
                            Button(group.shortName) { selectedGroup = group }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedGroup == group ? RunTheme.electricTeal : Color.secondary.opacity(0.15))
                                .foregroundStyle(selectedGroup == group ? RunTheme.midnightSlate : .primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                List(matching) { ex in
                    Button {
                        onSelect(ex)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(ex.muscleGroup.shortName) · \(ex.equipment.map(\.displayName).joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if favoriteSlugs.contains(ex.id) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(RunTheme.amber)
                            }
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(RunTheme.electricTeal)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
