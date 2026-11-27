import Charts
import SwiftData
import SwiftUI
import TrackerCore

struct InsightsDashboardView: View {
    @Environment(AppSettingsStore.self) private var settings

    @Query(sort: \SDActivity.startDate, order: .reverse) private var activities: [SDActivity]
    @Query private var goals: [SDGoal]
    @Query private var gearItems: [SDGear]

    @State private var timeframe: StatsTimeframe = .week

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

    private var filteredInputs: [ActivityStatsInput] {
        StatsAggregator.filter(statsInputs, timeframe: timeframe)
    }

    private var totalsByType: [TypeTotals] {
        StatsAggregator.totalsByType(statsInputs, timeframe: timeframe)
    }

    private var trendBuckets: [PeriodTrendBucket] {
        StatsAggregator.trendBuckets(activities: statsInputs, timeframe: timeframe)
    }

    private var streakSummary: StreakSummary {
        StatsAggregator.streaks(activities: statsInputs)
    }

    private var fitnessSeries: [FitnessTrendPoint] {
        StatsAggregator.fitnessFatigueTrend(activities: statsInputs, days: 45)
    }

    private var retiringGearCount: Int {
        gearItems.filter { gear in
            guard !gear.isRetired, gear.maxDistanceMeters > 0 else { return false }
            let logged = activities.filter { $0.gearID == gear.id }.reduce(0.0) { $0 + $1.distanceMeters }
            return (gear.initialDistanceMeters + logged) >= gear.maxDistanceMeters
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Timeframe", selection: $timeframe) {
                        ForEach(StatsTimeframe.allCases) { tf in
                            Text(tf.displayName).tag(tf)
                        }
                    }
                    .pickerStyle(.segmented)

                    summaryGrid
                    streaksCard
                    volumeTrendCard
                    typeBreakdownCard
                    fitnessFatigueCard
                    quickToolsSection
                }
                .padding(16)
            }
            .navigationTitle("Insights")
        }
    }

    @ViewBuilder
    private var summaryGrid: some View {
        let totalDist = filteredInputs.reduce(0.0) { $0 + $1.distanceMeters }
        let totalTime = filteredInputs.reduce(0.0) { $0 + $1.movingTime }
        let totalElev = filteredInputs.reduce(0.0) { $0 + $1.elevationGainMeters }
        let totalCals = filteredInputs.reduce(0.0) { $0 + $1.estimatedCalories }
        let unit = settings.unitSystem

        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            metricTile(title: "ACTIVITIES", value: "\(filteredInputs.count)", color: .primary)
            metricTile(title: "DISTANCE", value: RunFormatter.distance(meters: totalDist, unit: unit), color: RunTheme.electricTeal)
            metricTile(title: "MOVING TIME", value: RunFormatter.duration(seconds: totalTime), color: RunTheme.emerald)
            metricTile(title: "ELEV GAIN", value: RunFormatter.elevation(meters: totalElev, unit: unit), color: RunTheme.violet)
            metricTile(title: "EST. CALORIES (ESTIMATE)", value: "\(Int(totalCals.rounded())) kcal", color: .secondary)
        }
    }

    @ViewBuilder
    private func metricTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var streaksCard: some View {
        HStack(spacing: 12) {
            streakColumn(label: "DAY STREAK", value: "\(streakSummary.currentDayStreak)d", accent: RunTheme.electricTeal)
            Divider().frame(height: 34)
            streakColumn(label: "BEST DAYS", value: "\(streakSummary.longestDayStreak)d", accent: RunTheme.emerald)
            Divider().frame(height: 34)
            streakColumn(label: "WEEK STREAK", value: "\(streakSummary.currentWeekStreak)w", accent: RunTheme.violet)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func streakColumn(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(accent)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var volumeTrendCard: some View {
        let unit = settings.unitSystem

        VStack(alignment: .leading, spacing: 10) {
            Text("Distance Trend (\(unit.distanceUnitLabel))")
                .font(.headline)

            if trendBuckets.isEmpty {
                Text("No trend data available yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(trendBuckets) { bucket in
                    BarMark(
                        x: .value("Period", bucket.label),
                        y: .value("Distance", bucket.distanceMeters / unit.metersPerMajorUnit)
                    )
                    .foregroundStyle(RunTheme.electricTeal)
                    .cornerRadius(4)
                }
                .frame(height: 160)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var typeBreakdownCard: some View {
        let unit = settings.unitSystem

        VStack(alignment: .leading, spacing: 10) {
            Text("By Activity Type")
                .font(.headline)

            if totalsByType.isEmpty {
                Text("No activities in this timeframe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(totalsByType) { item in
                    HStack {
                        Label(item.activityType.displayName, systemImage: item.activityType.symbolName)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(item.count)×")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if item.activityType == .strength {
                            Text(RunFormatter.duration(seconds: item.movingTime))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(RunTheme.violet)
                        } else {
                            Text(RunFormatter.distance(meters: item.distanceMeters, unit: unit))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(RunTheme.electricTeal)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var fitnessFatigueCard: some View {
        let latest = fitnessSeries.last

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Fitness & Fatigue Trend")
                    .font(.headline)
                Spacer()
                Text("Estimate")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let latest {
                HStack(spacing: 12) {
                    Text("Fitness: \(Int(latest.fitness.rounded()))")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(RunTheme.electricTeal)
                    Text("Fatigue: \(Int(latest.fatigue.rounded()))")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(RunTheme.violet)
                    Text("Form: \(Int(latest.form.rounded()))")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(latest.form >= 0 ? RunTheme.emerald : RunTheme.amber)
                }
            }

            Chart {
                ForEach(fitnessSeries) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Load", point.fitness),
                        series: .value("Metric", "Fitness")
                    )
                    .foregroundStyle(RunTheme.electricTeal)
                    .lineStyle(StrokeStyle(lineWidth: 2.2))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Load", point.fatigue),
                        series: .value("Metric", "Fatigue")
                    )
                    .foregroundStyle(RunTheme.violet)
                    .lineStyle(StrokeStyle(lineWidth: 2.0, dash: [4, 3]))
                }
            }
            .frame(height: 150)

            Text("42-day fitness vs. 7-day fatigue exponentially weighted from heart-rate TRIMP (or pace/duration effort estimate when no HR data exists).")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var quickToolsSection: some View {
        VStack(spacing: 10) {
            NavigationLink(destination: PersonalRecordsView()) {
                toolRow(
                    title: "Personal Records",
                    subtitle: "1 km, 1 mi, 5 km, 10 km, Half, Marathon & Climbs",
                    icon: "trophy.fill",
                    tint: RunTheme.emerald,
                    badge: nil
                )
            }

            NavigationLink(destination: GoalsView()) {
                toolRow(
                    title: "Goals & Reminders",
                    subtitle: "\(goals.count) active goal\(goals.count == 1 ? "" : "s")",
                    icon: "target",
                    tint: RunTheme.electricTeal,
                    badge: nil
                )
            }

            NavigationLink(destination: GearView()) {
                toolRow(
                    title: "Gear Locker",
                    subtitle: "\(gearItems.count) item\(gearItems.count == 1 ? "" : "s")",
                    icon: "shoeprints.fill",
                    tint: RunTheme.violet,
                    badge: retiringGearCount > 0 ? "\(retiringGearCount) due" : nil
                )
            }

            if settings.featureFlags.personalSections {
                NavigationLink(destination: PersonalSectionsView()) {
                    toolRow(
                        title: "Personal Sections",
                        subtitle: "Match & rank your own timed segments",
                        icon: "flag.checkered.2.crossed",
                        tint: RunTheme.amber,
                        badge: nil
                    )
                }
            }

            if settings.featureFlags.personalHeatmap {
                NavigationLink(destination: PersonalHeatmapView()) {
                    toolRow(
                        title: "Personal Heatmap",
                        subtitle: "Overlay all of your own recorded routes",
                        icon: "flame.fill",
                        tint: RunTheme.coral,
                        badge: nil
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func toolRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        badge: String?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let badge {
                Text(badge)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RunTheme.coral.opacity(0.18))
                    .foregroundStyle(RunTheme.coral)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
