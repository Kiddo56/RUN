import Charts
import SwiftData
import SwiftUI
import TrackerCore

private enum ProgressChartMetric: String, CaseIterable, Identifiable {
    case estimated1RM = "Est. 1RM"
    case topSet = "Top Set"
    case volume = "Volume"

    var id: String { rawValue }
}

struct FitnessProgressView: View {
    @Environment(AppSettingsStore.self) private var settings

    @Query(sort: \SDWorkoutSession.startDate, order: .reverse) private var sessions: [SDWorkoutSession]
    @Query private var entries: [SDWorkoutExerciseEntry]
    @Query private var sets: [SDSetEntry]

    @State private var selectedExerciseSlug: String = ""
    @State private var chartMetric: ProgressChartMetric = .estimated1RM
    @State private var displayedMonth: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()

    private var completedSessions: [SDWorkoutSession] {
        sessions.filter(\.isCompleted)
    }

    private var loggedExerciseOptions: [(slug: String, name: String)] {
        var map: [String: String] = [:]
        for entry in entries {
            map[entry.exerciseSlug] = entry.exerciseNameSnapshot
        }
        return map.map { (slug: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
    }

    private var activeSlug: String {
        if !selectedExerciseSlug.isEmpty, loggedExerciseOptions.contains(where: { $0.slug == selectedExerciseSlug }) {
            return selectedExerciseSlug
        }
        return loggedExerciseOptions.first?.slug ?? ""
    }

    private var sessionDateMap: [UUID: Date] {
        Dictionary(uniqueKeysWithValues: completedSessions.map { ($0.id, $0.startDate) })
    }

    private var activeExerciseSnapshots: [StrengthSetSnapshot] {
        guard !activeSlug.isEmpty else { return [] }
        let dates = sessionDateMap
        return sets.compactMap { s in
            guard s.exerciseSlug == activeSlug,
                  s.isCompleted,
                  let workoutDate = dates[s.workoutSessionID] else { return nil }
            return StrengthSetSnapshot(
                id: s.id,
                workoutSessionID: s.workoutSessionID,
                workoutDate: workoutDate,
                exerciseSlug: s.exerciseSlug,
                setType: SetType(rawValue: s.setTypeRaw) ?? .normal,
                weightKg: s.weightKg,
                reps: s.reps,
                durationSeconds: s.durationSeconds,
                rpe: s.rpe,
                isCompleted: true
            )
        }
    }

    private var exerciseHistoryPoints: [ExerciseHistoryPoint] {
        StrengthEngine.buildExerciseHistory(sets: activeExerciseSnapshots)
    }

    private var exercisePRs: ExercisePRSnapshot {
        StrengthEngine.computeHistoricalPRs(sets: activeExerciseSnapshots)
    }

    private var weeklyMuscleVolumes: [MuscleGroupWeeklyVolume] {
        let dates = sessionDateMap
        let entryGroupMap = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, MuscleGroup(rawValue: $0.muscleGroupRaw) ?? .fullBody) })
        let items: [(muscleGroup: MuscleGroup, set: StrengthSetSnapshot)] = sets.compactMap { s in
            guard s.isCompleted,
                  let date = dates[s.workoutSessionID],
                  let group = entryGroupMap[s.workoutExerciseEntryID] else { return nil }
            let snap = StrengthSetSnapshot(
                id: s.id,
                workoutSessionID: s.workoutSessionID,
                workoutDate: date,
                exerciseSlug: s.exerciseSlug,
                setType: SetType(rawValue: s.setTypeRaw) ?? .normal,
                weightKg: s.weightKg,
                reps: s.reps,
                durationSeconds: s.durationSeconds,
                rpe: s.rpe,
                isCompleted: true
            )
            return (group, snap)
        }
        return StrengthEngine.weeklyVolumeByMuscleGroup(entries: items)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if completedSessions.isEmpty {
                    ContentUnavailableView(
                        "No Strength Progress Yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Complete your first strength workout to unlock 1RM trends, personal records, muscle volume charts, and your training calendar.")
                    )
                    .padding(.top, 28)
                } else {
                    exerciseProgressionCard
                    weeklyMuscleVolumeCard
                    trainingFrequencyCalendarCard
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var exerciseProgressionCard: some View {
        let unit = settings.weightUnit
        let history = exerciseHistoryPoints
        let prs = exercisePRs

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercise Progress")
                    .font(.headline)
                Spacer()
                if !loggedExerciseOptions.isEmpty {
                    Picker("Exercise", selection: Binding(
                        get: { activeSlug },
                        set: { selectedExerciseSlug = $0 }
                    )) {
                        ForEach(loggedExerciseOptions, id: \.slug) { opt in
                            Text(opt.name).tag(opt.slug)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                prChip(title: "HEAVIEST", value: RunFormatter.weight(kg: prs.heaviestWeightKg, unit: unit), color: RunTheme.electricTeal)
                prChip(title: "BEST EST. 1RM", value: RunFormatter.weight(kg: prs.bestEstimated1RMKg, unit: unit), color: RunTheme.emerald)
                prChip(title: "MOST REPS", value: "\(prs.mostReps) reps", color: RunTheme.amber)
                prChip(title: "BEST VOLUME", value: RunFormatter.volume(kg: prs.bestSessionVolumeKg, unit: unit), color: RunTheme.violet)
            }

            Picker("Metric", selection: $chartMetric) {
                ForEach(ProgressChartMetric.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            if history.isEmpty {
                Text("Log working sets for this exercise to chart progression.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                exerciseChartView(points: history, unit: unit)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func exerciseChartView(points: [ExerciseHistoryPoint], unit: WeightUnit) -> some View {
        Chart(points) { pt in
            LineMark(
                x: .value("Date", pt.date),
                y: .value(chartMetric.rawValue, chartValue(for: pt, unit: unit))
            )
            .foregroundStyle(RunTheme.electricTeal)
            .lineStyle(StrokeStyle(lineWidth: 2.5))

            PointMark(
                x: .value("Date", pt.date),
                y: .value(chartMetric.rawValue, chartValue(for: pt, unit: unit))
            )
            .foregroundStyle(RunTheme.emerald)
        }
        .frame(height: 170)
    }

    private func chartValue(for pt: ExerciseHistoryPoint, unit: WeightUnit) -> Double {
        switch chartMetric {
        case .estimated1RM:
            return unit.fromKilograms(pt.bestEstimated1RMKg)
        case .topSet:
            return unit.fromKilograms(pt.topSetWeightKg)
        case .volume:
            return unit.fromKilograms(pt.totalVolumeKg)
        }
    }

    @ViewBuilder
    private func prChip(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var weeklyMuscleVolumeCard: some View {
        let volumes = weeklyMuscleVolumes
        let unit = settings.weightUnit

        VStack(alignment: .leading, spacing: 10) {
            Text("This Week's Muscle Volume (\(unit.symbol))")
                .font(.headline)

            if volumes.isEmpty {
                Text("No working sets logged this week yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(volumes) { item in
                    BarMark(
                        x: .value("Volume", unit.fromKilograms(item.volumeKg)),
                        y: .value("Muscle", item.muscleGroup.shortName)
                    )
                    .foregroundStyle(RunTheme.violet)
                    .cornerRadius(4)
                }
                .frame(height: CGFloat(max(130, volumes.count * 34)))

                ForEach(volumes) { item in
                    HStack {
                        Text(item.muscleGroup.shortName)
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("\(item.workingSets) sets · \(RunFormatter.volume(kg: item.volumeKg, unit: unit))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var trainingFrequencyCalendarCard: some View {
        let cal = Calendar.current
        let workoutDays = Set(completedSessions.map { cal.startOfDay(for: $0.startDate) })
        let slots = monthSlots(for: displayedMonth, calendar: cal)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Training Frequency")
                    .font(.headline)
                Spacer()
                Button {
                    if let prev = cal.date(byAdding: .month, value: -1, to: displayedMonth) {
                        displayedMonth = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                Text(displayedMonth.formatted(.dateTime.month(.abbreviated).year()))
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 74)
                Button {
                    if let next = cal.date(byAdding: .month, value: 1, to: displayedMonth) {
                        displayedMonth = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(slots.enumerated()), id: \.offset) { _, dateOpt in
                    if let date = dateOpt {
                        let dayStart = cal.startOfDay(for: date)
                        let trained = workoutDays.contains(dayStart)
                        Text("\(cal.component(.day, from: date))")
                            .font(.caption.weight(trained ? .bold : .regular).monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(trained ? RunTheme.emerald : Color.clear)
                            .foregroundStyle(trained ? RunTheme.midnightSlate : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func monthSlots(for month: Date, calendar: Calendar) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        for d in 0..<range.count {
            if let dt = calendar.date(byAdding: .day, value: d, to: first) {
                result.append(dt)
            }
        }
        return result
    }
}
