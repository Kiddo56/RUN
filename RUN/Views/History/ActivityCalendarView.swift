import SwiftUI
import TrackerCore

struct ActivityCalendarView: View {
    let activities: [SDActivity]
    var workoutSessions: [SDWorkoutSession] = []
    let unitSystem: UnitSystem
    var weightUnit: WeightUnit = .kg

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    private let calendar = Calendar.current

    private var activitiesByDay: [Date: [SDActivity]] {
        Dictionary(grouping: activities) { activity in
            calendar.startOfDay(for: activity.startDate)
        }
    }

    private var monthActivities: [SDActivity] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        return activities.filter { $0.startDate >= interval.start && $0.startDate < interval.end }
    }

    private var selectedDayActivities: [SDActivity] {
        activitiesByDay[calendar.startOfDay(for: selectedDay)] ?? []
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let offset = max(0, calendar.firstWeekday - 1)
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var monthDaySlots: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7
        var slots: [Date?] = Array(repeating: nil, count: leadingBlanks)

        for dayOffset in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) {
                slots.append(date)
            }
        }
        return slots
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthHeader
                monthSummaryBar
                calendarGrid
                selectedDaySection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title3.weight(.bold))

            Spacer()

            Button("Today") {
                let now = Date()
                displayedMonth = calendar.startOfMonth(for: now)
                selectedDay = calendar.startOfDay(for: now)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RunTheme.electricTeal.opacity(0.16))
            .foregroundStyle(RunTheme.electricTeal)
            .clipShape(Capsule())

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Next month")
        }
    }

    @ViewBuilder
    private var monthSummaryBar: some View {
        let totalDist = monthActivities.reduce(0.0) { $0 + $1.distanceMeters }
        let totalTime = monthActivities.reduce(0.0) { $0 + $1.movingTime }

        HStack(spacing: 12) {
            summaryPill(title: "ACTIVITIES", value: "\(monthActivities.count)")
            summaryPill(title: "DISTANCE", value: RunFormatter.distance(meters: totalDist, unit: unitSystem))
            summaryPill(title: "MOVING TIME", value: RunFormatter.duration(seconds: totalTime))
        }
    }

    @ViewBuilder
    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(monthDaySlots.enumerated()), id: \.offset) { _, dateOpt in
                    if let date = dateOpt {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let dayStart = calendar.startOfDay(for: date)
        let isSelected = calendar.isDate(dayStart, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(dayStart)
        let dayCount = activitiesByDay[dayStart]?.count ?? 0

        Button {
            selectedDay = dayStart
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(isSelected || isToday ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(isSelected ? RunTheme.midnightSlate : (isToday ? RunTheme.electricTeal : .primary))

                if dayCount > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(3, dayCount), id: \.self) { _ in
                            Circle()
                                .fill(isSelected ? RunTheme.midnightSlate : RunTheme.electricTeal)
                                .frame(width: 5, height: 5)
                        }
                    }
                } else {
                    Spacer().frame(height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? RunTheme.electricTeal : (dayCount > 0 ? RunTheme.electricTeal.opacity(0.10) : Color.clear))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDay.formatted(date: .complete, time: .omitted))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if selectedDayActivities.isEmpty {
                Text("No activities recorded on this day.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                let sessionByLinkedID = Dictionary(
                    uniqueKeysWithValues: workoutSessions.compactMap { s in
                        s.linkedActivityID.map { ($0, s) }
                    }
                )
                ForEach(selectedDayActivities) { activity in
                    if activity.activityType == .strength, let session = sessionByLinkedID[activity.id] {
                        NavigationLink(destination: WorkoutDetailView(session: session)) {
                            StrengthActivityRowCard(activity: activity, session: session, weightUnit: weightUnit)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(destination: ActivityDetailView(activity: activity)) {
                            ActivityRowCard(activity: activity, unitSystem: unitSystem)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shiftMonth(by delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = calendar.startOfMonth(for: next)
            selectedDay = displayedMonth
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? startOfDay(for: date)
    }
}
