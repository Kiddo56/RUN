import SwiftData
import SwiftUI
import TrackerCore

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @Query(sort: \SDGoal.createdAt, order: .reverse) private var goals: [SDGoal]
    @Query private var activities: [SDActivity]

    @State private var showingAddGoal = false

    private var statsInputs: [ActivityStatsInput] {
        activities.map {
            ActivityStatsInput(
                id: $0.id,
                title: $0.title,
                activityType: $0.activityType,
                startDate: $0.startDate,
                movingTime: $0.movingTime,
                distanceMeters: $0.distanceMeters,
                elevationGainMeters: $0.elevationGainMeters,
                effortScore: $0.effortScore,
                estimatedCalories: $0.estimatedCalories,
                gearID: $0.gearID
            )
        }
    }

    var body: some View {
        Group {
            if goals.isEmpty {
                ContentUnavailableView(
                    "No Goals Set",
                    systemImage: "target",
                    description: Text("Create weekly or monthly distance and time goals with optional local reminders.")
                )
            } else {
                List {
                    ForEach(goals) { goal in
                        goalRow(goal)
                    }
                    .onDelete(perform: deleteGoals)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddGoal = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Goal")
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalSheet()
        }
    }

    @ViewBuilder
    private func goalRow(_ goal: SDGoal) -> some View {
        let typeFilter = goal.activityTypeRaw.flatMap { ActivityType(rawValue: $0) }
        let achieved = StatsAggregator.goalProgress(
            activities: statsInputs,
            periodRaw: goal.periodRaw,
            metricRaw: goal.metricRaw,
            activityTypeFilter: typeFilter
        )
        let ratio = goal.targetValue > 0 ? (achieved / goal.targetValue) : 0
        let ringColor: Color = ratio >= 1.0 ? RunTheme.emerald : RunTheme.electricTeal

        HStack(spacing: 14) {
            GoalProgressRing(progress: ratio, color: ringColor)
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(goal.title)
                        .font(.headline)
                    if goal.reminderEnabled {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundStyle(RunTheme.electricTeal)
                    }
                }

                Text("\(goal.periodRaw.capitalized) · \(typeFilter?.displayName ?? "All Activities")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(progressCaption(goal: goal, achieved: achieved))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(ratio >= 1.0 ? RunTheme.emerald : .primary)
            }
        }
        .padding(.vertical, 4)
    }

    private func progressCaption(goal: SDGoal, achieved: Double) -> String {
        if goal.metricRaw == "movingTime" {
            return "\(RunFormatter.duration(seconds: achieved)) / \(RunFormatter.duration(seconds: goal.targetValue))"
        }
        let unit = settings.unitSystem
        return "\(RunFormatter.distance(meters: achieved, unit: unit)) / \(RunFormatter.distance(meters: goal.targetValue, unit: unit))"
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            let goal = goals[index]
            NotificationService.shared.cancelGoalReminder(goalID: goal.id)
            modelContext.delete(goal)
        }
        try? modelContext.save()
    }
}

struct GoalProgressRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        let clamped = min(1.0, max(0.0, progress))
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 6)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded()))%")
                .font(.caption2.weight(.bold).monospacedDigit())
        }
    }
}

struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @State private var title: String = ""
    @State private var periodRaw: String = "weekly"
    @State private var metricRaw: String = "distanceMeters"
    @State private var activityFilter: ActivityType? = .run
    @State private var targetInput: String = "25"
    @State private var reminderEnabled: Bool = false
    @State private var reminderWeekday: Int = 6 // Friday
    @State private var reminderHour: Int = 18

    private var targetUnitLabel: String {
        if metricRaw == "movingTime" { return "minutes" }
        return settings.unitSystem.distanceUnitLabel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Definition") {
                    TextField("Goal Title (e.g. Weekly Run Volume)", text: $title)

                    Picker("Period", selection: $periodRaw) {
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }
                    .pickerStyle(.segmented)

                    Picker("Metric", selection: $metricRaw) {
                        Text("Distance").tag("distanceMeters")
                        Text("Moving Time").tag("movingTime")
                    }
                    .pickerStyle(.segmented)

                    Picker("Activity Type", selection: $activityFilter) {
                        Text("All Activities").tag(Optional<ActivityType>.none)
                        ForEach(ActivityType.allCases) { type in
                            Text(type.displayName).tag(Optional(type))
                        }
                    }

                    HStack {
                        Text("Target (\(targetUnitLabel))")
                        Spacer()
                        TextField("25", text: $targetInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }

                Section {
                    Toggle("Weekly Local Reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        Picker("Day", selection: $reminderWeekday) {
                            Text("Sunday").tag(1)
                            Text("Monday").tag(2)
                            Text("Tuesday").tag(3)
                            Text("Wednesday").tag(4)
                            Text("Thursday").tag(5)
                            Text("Friday").tag(6)
                            Text("Saturday").tag(7)
                        }
                        Picker("Hour", selection: $reminderHour) {
                            ForEach(5..<22, id: \.self) { hr in
                                Text(String(format: "%02d:00", hr)).tag(hr)
                            }
                        }
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("Uses on-device local notifications only.")
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveGoal() }
                        .disabled(parsedTargetBaseValue <= 0)
                }
            }
        }
    }

    private var parsedTargetBaseValue: Double {
        let raw = Double(targetInput.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard raw > 0 else { return 0 }
        if metricRaw == "movingTime" {
            return raw * 60.0
        }
        return raw * settings.unitSystem.metersPerMajorUnit
    }

    private func saveGoal() {
        let targetVal = parsedTargetBaseValue
        guard targetVal > 0 else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty
            ? "\(periodRaw.capitalized) \(activityFilter?.displayName ?? "Activity") Goal"
            : cleanTitle

        let goal = SDGoal(
            title: finalTitle,
            periodRaw: periodRaw,
            metricRaw: metricRaw,
            targetValue: targetVal,
            activityTypeRaw: activityFilter?.rawValue,
            reminderEnabled: reminderEnabled,
            reminderWeekday: reminderWeekday,
            reminderHour: reminderHour
        )
        modelContext.insert(goal)
        try? modelContext.save()

        if reminderEnabled {
            let goalID = goal.id
            let gTitle = goal.title
            let wDay = reminderWeekday
            let hr = reminderHour
            Task {
                await NotificationService.shared.scheduleGoalReminder(
                    goalID: goalID,
                    title: gTitle,
                    weekday: wDay,
                    hour: hr
                )
            }
        }
        dismiss()
    }
}
