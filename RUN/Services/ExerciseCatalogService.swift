import Foundation
import Observation
import SwiftData
import TrackerCore

@MainActor
@Observable
final class ExerciseCatalogService {
    static let shared = ExerciseCatalogService()

    private(set) var catalogVersion: Int = 1
    private(set) var builtInExercises: [CatalogExercise] = []
    private(set) var loadError: String?

    private var bySlug: [String: CatalogExercise] = [:]

    private init() {
        loadBundledCatalog()
    }

    func loadBundledCatalog(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "exercises", withExtension: "json") else {
            loadError = "Bundled exercises.json resource not found."
            DiagnosticsLogger.shared.log(.error, "ExerciseCatalogService: exercises.json missing from bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let doc = try JSONDecoder().decode(ExerciseCatalogDocument.self, from: data)
            self.catalogVersion = doc.catalogVersion
            self.builtInExercises = doc.exercises
            self.bySlug = Dictionary(uniqueKeysWithValues: doc.exercises.map { ($0.id, $0) })
            self.loadError = nil
        } catch {
            self.loadError = error.localizedDescription
            DiagnosticsLogger.shared.log(.error, "ExerciseCatalogService decode failed: \(error.localizedDescription)")
        }
    }

    func allExercises(custom customModels: [SDCustomExercise]) -> [CatalogExercise] {
        let converted = customModels.map { convertCustom($0) }
        return (builtInExercises + converted).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func exercise(forSlug slug: String, custom customModels: [SDCustomExercise] = []) -> CatalogExercise? {
        if let builtIn = bySlug[slug] {
            return builtIn
        }
        if let match = customModels.first(where: { $0.slug == slug }) {
            return convertCustom(match)
        }
        return nil
    }

    func convertCustom(_ model: SDCustomExercise) -> CatalogExercise {
        let group = MuscleGroup(rawValue: model.muscleGroupRaw) ?? .fullBody
        let equip = model.equipmentCSV
            .split(separator: ",")
            .compactMap { ExerciseEquipment(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
        let primary = model.primaryMusclesCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let secondary = model.secondaryMusclesCSV
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let steps = model.instructionsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return CatalogExercise(
            id: model.slug,
            name: model.name,
            aliases: [],
            muscleGroup: group,
            primaryMuscles: primary.isEmpty ? [group.shortName] : primary,
            secondaryMuscles: secondary,
            equipment: equip.isEmpty ? [.bodyweight] : equip,
            mechanic: ExerciseMechanic(rawValue: model.mechanicRaw) ?? .compound,
            difficulty: ExerciseDifficulty(rawValue: model.difficultyRaw) ?? .intermediate,
            trackingType: ExerciseTrackingType(rawValue: model.trackingTypeRaw) ?? .weightReps,
            instructions: steps.isEmpty ? ["Perform each repetition with steady control through a comfortable range of motion."] : steps,
            tips: model.tips,
            commonMistakes: model.commonMistakes,
            isCustom: true
        )
    }

    // MARK: - 9 Prebuilt Original Workout Templates

    func seedBuiltInTemplatesIfNeeded(modelContext: ModelContext) {
        let existing = (try? modelContext.fetch(FetchDescriptor<SDWorkoutTemplate>())) ?? []
        let existingKeys = Set(existing.compactMap(\.builtInKey))

        struct TemplateItemSeed {
            let slug: String
            let sets: Int
            let repMin: Int
            let repMax: Int
            let durationSec: Int
            let restSec: Int
        }
        struct TemplateSeed {
            let key: String
            let name: String
            let notes: String
            let items: [TemplateItemSeed]
        }

        let seeds: [TemplateSeed] = [
            TemplateSeed(
                key: "leg-day",
                name: "Leg Day",
                notes: "Balanced lower-body strength focused on quads, hamstrings, glutes, and calves.",
                items: [
                    TemplateItemSeed(slug: "barbell-back-squat", sets: 4, repMin: 6, repMax: 8, durationSec: 0, restSec: 150),
                    TemplateItemSeed(slug: "barbell-romanian-deadlift", sets: 3, repMin: 8, repMax: 10, durationSec: 0, restSec: 120),
                    TemplateItemSeed(slug: "bulgarian-split-squat", sets: 3, repMin: 8, repMax: 10, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "lying-leg-curl", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 75),
                    TemplateItemSeed(slug: "standing-calf-raise", sets: 4, repMin: 12, repMax: 15, durationSec: 0, restSec: 60)
                ]
            ),
            TemplateSeed(
                key: "push-day",
                name: "Push Day",
                notes: "Chest, shoulders, and triceps pressing progression.",
                items: [
                    TemplateItemSeed(slug: "barbell-bench-press", sets: 4, repMin: 6, repMax: 8, durationSec: 0, restSec: 120),
                    TemplateItemSeed(slug: "incline-dumbbell-press", sets: 3, repMin: 8, repMax: 10, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "seated-dumbbell-shoulder-press", sets: 3, repMin: 8, repMax: 10, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "dumbbell-lateral-raise", sets: 3, repMin: 12, repMax: 15, durationSec: 0, restSec: 60),
                    TemplateItemSeed(slug: "cable-rope-pushdown", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 60)
                ]
            ),
            TemplateSeed(
                key: "pull-day",
                name: "Pull Day",
                notes: "Vertical and horizontal back pulling plus rear delts and biceps.",
                items: [
                    TemplateItemSeed(slug: "pull-up", sets: 3, repMin: 6, repMax: 10, durationSec: 0, restSec: 120),
                    TemplateItemSeed(slug: "barbell-bent-over-row", sets: 4, repMin: 6, repMax: 8, durationSec: 0, restSec: 120),
                    TemplateItemSeed(slug: "seated-cable-row", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "face-pull-cable", sets: 3, repMin: 12, repMax: 15, durationSec: 0, restSec: 60),
                    TemplateItemSeed(slug: "dumbbell-alternating-curl", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 60)
                ]
            ),
            TemplateSeed(
                key: "upper-body",
                name: "Upper Body",
                notes: "Complete upper-body compound and accessory split.",
                items: [
                    TemplateItemSeed(slug: "dumbbell-bench-press", sets: 4, repMin: 8, repMax: 10, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "single-arm-dumbbell-row", sets: 4, repMin: 8, repMax: 10, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "overhead-barbell-press", sets: 3, repMin: 6, repMax: 8, durationSec: 0, restSec: 120),
                    TemplateItemSeed(slug: "lat-pulldown", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "hammer-curl", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 60),
                    TemplateItemSeed(slug: "cable-overhead-tricep-extension", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 60)
                ]
            ),
            TemplateSeed(
                key: "lower-body",
                name: "Lower Body",
                notes: "Quad, posterior chain, and unilateral leg balance.",
                items: [
                    TemplateItemSeed(slug: "goblet-squat", sets: 4, repMin: 8, repMax: 10, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "dumbbell-romanian-deadlift", sets: 4, repMin: 8, repMax: 10, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "barbell-hip-thrust", sets: 3, repMin: 8, repMax: 12, durationSec: 0, restSec: 120),
                    TemplateItemSeed(slug: "walking-lunge", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "seated-calf-raise", sets: 3, repMin: 12, repMax: 15, durationSec: 0, restSec: 60)
                ]
            ),
            TemplateSeed(
                key: "arms-day",
                name: "Arms Day",
                notes: "Dedicated biceps, triceps, and forearm work.",
                items: [
                    TemplateItemSeed(slug: "barbell-bicep-curl", sets: 3, repMin: 8, repMax: 10, durationSec: 0, restSec: 75),
                    TemplateItemSeed(slug: "ez-bar-skull-crusher", sets: 3, repMin: 8, repMax: 10, durationSec: 0, restSec: 75),
                    TemplateItemSeed(slug: "incline-dumbbell-curl", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 60),
                    TemplateItemSeed(slug: "cable-rope-pushdown", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 60),
                    TemplateItemSeed(slug: "hammer-curl", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 60),
                    TemplateItemSeed(slug: "dumbbell-wrist-curl", sets: 3, repMin: 12, repMax: 15, durationSec: 0, restSec: 45)
                ]
            ),
            TemplateSeed(
                key: "full-body-beginner",
                name: "Full Body Beginner",
                notes: "Approachable three-day-a-week foundational full-body routine.",
                items: [
                    TemplateItemSeed(slug: "goblet-squat", sets: 3, repMin: 8, repMax: 12, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "standard-push-up", sets: 3, repMin: 8, repMax: 12, durationSec: 0, restSec: 75),
                    TemplateItemSeed(slug: "single-arm-dumbbell-row", sets: 3, repMin: 8, repMax: 12, durationSec: 0, restSec: 75),
                    TemplateItemSeed(slug: "dumbbell-romanian-deadlift", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 90),
                    TemplateItemSeed(slug: "seated-dumbbell-shoulder-press", sets: 3, repMin: 8, repMax: 12, durationSec: 0, restSec: 75),
                    TemplateItemSeed(slug: "front-forearm-plank", sets: 3, repMin: 0, repMax: 0, durationSec: 30, restSec: 60)
                ]
            ),
            TemplateSeed(
                key: "core-finisher",
                name: "Core Finisher",
                notes: "Short anti-extension, anti-rotation, and trunk endurance circuit.",
                items: [
                    TemplateItemSeed(slug: "front-forearm-plank", sets: 3, repMin: 0, repMax: 0, durationSec: 45, restSec: 45),
                    TemplateItemSeed(slug: "dead-bug", sets: 3, repMin: 12, repMax: 16, durationSec: 0, restSec: 45),
                    TemplateItemSeed(slug: "side-plank-hold", sets: 2, repMin: 0, repMax: 0, durationSec: 30, restSec: 45),
                    TemplateItemSeed(slug: "hollow-body-hold", sets: 3, repMin: 0, repMax: 0, durationSec: 25, restSec: 45),
                    TemplateItemSeed(slug: "reverse-crunch", sets: 3, repMin: 12, repMax: 15, durationSec: 0, restSec: 45)
                ]
            ),
            TemplateSeed(
                key: "home-bodyweight-circuit",
                name: "Home Bodyweight Circuit",
                notes: "Zero-equipment full-body training you can run anywhere.",
                items: [
                    TemplateItemSeed(slug: "bodyweight-air-squat", sets: 3, repMin: 15, repMax: 20, durationSec: 0, restSec: 60),
                    TemplateItemSeed(slug: "standard-push-up", sets: 3, repMin: 10, repMax: 15, durationSec: 0, restSec: 60),
                    TemplateItemSeed(slug: "reverse-lunge", sets: 3, repMin: 10, repMax: 12, durationSec: 0, restSec: 60),
                    TemplateItemSeed(slug: "glute-bridge-bodyweight", sets: 3, repMin: 15, repMax: 20, durationSec: 0, restSec: 45),
                    TemplateItemSeed(slug: "pike-push-up", sets: 3, repMin: 8, repMax: 12, durationSec: 0, restSec: 60),
                    TemplateItemSeed(slug: "mountain-climber-slow", sets: 3, repMin: 0, repMax: 0, durationSec: 30, restSec: 45)
                ]
            )
        ]

        var insertedAny = false
        for seed in seeds where !existingKeys.contains(seed.key) {
            let template = SDWorkoutTemplate(
                name: seed.name,
                notes: seed.notes,
                isBuiltIn: true,
                builtInKey: seed.key
            )
            modelContext.insert(template)
            for (idx, item) in seed.items.enumerated() {
                let name = bySlug[item.slug]?.name ?? item.slug.replacingOccurrences(of: "-", with: " ").capitalized
                let row = SDWorkoutTemplateItem(
                    templateID: template.id,
                    exerciseSlug: item.slug,
                    exerciseNameSnapshot: name,
                    orderIndex: idx,
                    targetSets: item.sets,
                    targetRepsMin: item.repMin,
                    targetRepsMax: item.repMax,
                    targetDurationSeconds: item.durationSec,
                    defaultRestSeconds: item.restSec
                )
                modelContext.insert(row)
            }
            insertedAny = true
        }
        if insertedAny {
            try? modelContext.save()
        }
    }
}
