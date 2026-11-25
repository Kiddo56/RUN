import Foundation

public struct ActivityStatsInput: Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let activityType: ActivityType
    public let startDate: Date
    public let movingTime: TimeInterval
    public let distanceMeters: Double
    public let elevationGainMeters: Double
    public let effortScore: Double
    public let estimatedCalories: Double
    public let gearID: UUID?

    public init(
        id: UUID,
        title: String,
        activityType: ActivityType,
        startDate: Date,
        movingTime: TimeInterval,
        distanceMeters: Double,
        elevationGainMeters: Double,
        effortScore: Double,
        estimatedCalories: Double,
        gearID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.activityType = activityType
        self.startDate = startDate
        self.movingTime = movingTime
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.effortScore = effortScore
        self.estimatedCalories = estimatedCalories
        self.gearID = gearID
    }
}

public enum StatsTimeframe: String, CaseIterable, Sendable, Identifiable {
    case week
    case month
    case year
    case allTime

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .allTime: return "All Time"
        }
    }
}

public struct TypeTotals: Identifiable, Sendable, Equatable {
    public let activityType: ActivityType
    public let count: Int
    public let distanceMeters: Double
    public let movingTime: TimeInterval
    public let elevationGainMeters: Double
    public let estimatedCalories: Double
    public let effortScore: Double

    public var id: ActivityType { activityType }
}

public struct PeriodTrendBucket: Identifiable, Sendable, Equatable {
    public let label: String
    public let startDate: Date
    public let distanceMeters: Double
    public let movingTime: TimeInterval
    public let elevationGainMeters: Double
    public let count: Int

    public var id: Date { startDate }
}

public struct StreakSummary: Sendable, Equatable {
    public let currentDayStreak: Int
    public let longestDayStreak: Int
    public let currentWeekStreak: Int
    public let longestWeekStreak: Int
}

public struct FitnessTrendPoint: Identifiable, Sendable, Equatable {
    public let date: Date
    public let dailyEffort: Double
    public let fitness: Double
    public let fatigue: Double
    public let form: Double

    public var id: Date { date }
}

public enum StatsAggregator {
    public static func filter(
        _ activities: [ActivityStatsInput],
        timeframe: StatsTimeframe,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [ActivityStatsInput] {
        switch timeframe {
        case .allTime:
            return activities
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return activities }
            return activities.filter { $0.startDate >= interval.start && $0.startDate < interval.end }
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: referenceDate) else { return activities }
            return activities.filter { $0.startDate >= interval.start && $0.startDate < interval.end }
        case .year:
            guard let interval = calendar.dateInterval(of: .year, for: referenceDate) else { return activities }
            return activities.filter { $0.startDate >= interval.start && $0.startDate < interval.end }
        }
    }

    public static func totalsByType(
        _ activities: [ActivityStatsInput],
        timeframe: StatsTimeframe,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [TypeTotals] {
        let filtered = filter(activities, timeframe: timeframe, referenceDate: referenceDate, calendar: calendar)
        var grouped: [ActivityType: [ActivityStatsInput]] = [:]
        for item in filtered {
            grouped[item.activityType, default: []].append(item)
        }

        var totals: [TypeTotals] = []
        for (type, list) in grouped {
            totals.append(
                TypeTotals(
                    activityType: type,
                    count: list.count,
                    distanceMeters: list.reduce(0.0) { $0 + $1.distanceMeters },
                    movingTime: list.reduce(0.0) { $0 + $1.movingTime },
                    elevationGainMeters: list.reduce(0.0) { $0 + $1.elevationGainMeters },
                    estimatedCalories: list.reduce(0.0) { $0 + $1.estimatedCalories },
                    effortScore: list.reduce(0.0) { $0 + $1.effortScore }
                )
            )
        }
        return totals.sorted {
            if $0.distanceMeters != $1.distanceMeters {
                return $0.distanceMeters > $1.distanceMeters
            }
            return $0.count > $1.count
        }
    }

    public static func streaks(
        activities: [ActivityStatsInput],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> StreakSummary {
        guard !activities.isEmpty else {
            return StreakSummary(currentDayStreak: 0, longestDayStreak: 0, currentWeekStreak: 0, longestWeekStreak: 0)
        }

        let activeDays = Set(activities.map { calendar.startOfDay(for: $0.startDate) })
        let today = calendar.startOfDay(for: referenceDate)

        var currentDayStreak = 0
        var dayCursor: Date?
        if activeDays.contains(today) {
            dayCursor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), activeDays.contains(yesterday) {
            dayCursor = yesterday
        }
        while let cursor = dayCursor, activeDays.contains(cursor) {
            currentDayStreak += 1
            dayCursor = calendar.date(byAdding: .day, value: -1, to: cursor)
        }

        let sortedDays = activeDays.sorted()
        var longestDayStreak = 0
        var runDays = 0
        var prevDay: Date?
        for day in sortedDays {
            if let prev = prevDay, calendar.dateComponents([.day], from: prev, to: day).day == 1 {
                runDays += 1
            } else {
                runDays = 1
            }
            longestDayStreak = max(longestDayStreak, runDays)
            prevDay = day
        }

        let activeWeeks = Set(activities.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0.startDate)?.start })
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
        var currentWeekStreak = 0
        var weekCursor: Date?
        if let thisWeekStart, activeWeeks.contains(thisWeekStart) {
            weekCursor = thisWeekStart
        } else if let thisWeekStart,
                  let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart),
                  activeWeeks.contains(lastWeek) {
            weekCursor = lastWeek
        }
        while let cursor = weekCursor, activeWeeks.contains(cursor) {
            currentWeekStreak += 1
            weekCursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor)
        }

        let sortedWeeks = activeWeeks.sorted()
        var longestWeekStreak = 0
        var runWeeks = 0
        var prevWeek: Date?
        for wk in sortedWeeks {
            if let prev = prevWeek,
               let expectedNext = calendar.date(byAdding: .weekOfYear, value: 1, to: prev),
               abs(expectedNext.timeIntervalSince(wk)) < 86400 {
                runWeeks += 1
            } else {
                runWeeks = 1
            }
            longestWeekStreak = max(longestWeekStreak, runWeeks)
            prevWeek = wk
        }

        return StreakSummary(
            currentDayStreak: currentDayStreak,
            longestDayStreak: longestDayStreak,
            currentWeekStreak: currentWeekStreak,
            longestWeekStreak: longestWeekStreak
        )
    }

    public static func trendBuckets(
        activities: [ActivityStatsInput],
        timeframe: StatsTimeframe,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [PeriodTrendBucket] {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let weekFormatter = DateFormatter()
        weekFormatter.dateFormat = "M/d"

        switch timeframe {
        case .week:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return [] }
            return (0..<7).compactMap { offset in
                guard let dayStart = calendar.date(byAdding: .day, value: offset, to: weekInterval.start),
                      let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
                let items = activities.filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
                return PeriodTrendBucket(
                    label: dayFormatter.string(from: dayStart),
                    startDate: dayStart,
                    distanceMeters: items.reduce(0.0) { $0 + $1.distanceMeters },
                    movingTime: items.reduce(0.0) { $0 + $1.movingTime },
                    elevationGainMeters: items.reduce(0.0) { $0 + $1.elevationGainMeters },
                    count: items.count
                )
            }

        case .month:
            guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else { return [] }
            return (-7...0).compactMap { offset in
                guard let wkStart = calendar.date(byAdding: .weekOfYear, value: offset, to: currentWeek),
                      let wkEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: wkStart) else { return nil }
                let items = activities.filter { $0.startDate >= wkStart && $0.startDate < wkEnd }
                return PeriodTrendBucket(
                    label: weekFormatter.string(from: wkStart),
                    startDate: wkStart,
                    distanceMeters: items.reduce(0.0) { $0 + $1.distanceMeters },
                    movingTime: items.reduce(0.0) { $0 + $1.movingTime },
                    elevationGainMeters: items.reduce(0.0) { $0 + $1.elevationGainMeters },
                    count: items.count
                )
            }

        case .year, .allTime:
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))
                ?? calendar.startOfDay(for: referenceDate)
            return (-11...0).compactMap { offset in
                guard let mStart = calendar.date(byAdding: .month, value: offset, to: currentMonthStart),
                      let mEnd = calendar.date(byAdding: .month, value: 1, to: mStart) else { return nil }
                let items = activities.filter { $0.startDate >= mStart && $0.startDate < mEnd }
                return PeriodTrendBucket(
                    label: monthFormatter.string(from: mStart),
                    startDate: mStart,
                    distanceMeters: items.reduce(0.0) { $0 + $1.distanceMeters },
                    movingTime: items.reduce(0.0) { $0 + $1.movingTime },
                    elevationGainMeters: items.reduce(0.0) { $0 + $1.elevationGainMeters },
                    count: items.count
                )
            }
        }
    }

    public static func fitnessFatigueTrend(
        activities: [ActivityStatsInput],
        days: Int = 60,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [FitnessTrendPoint] {
        let countDays = max(7, days)
        let endDay = calendar.startOfDay(for: referenceDate)
        let warmupDays = 90
        let totalSpan = countDays + warmupDays

        var effortByDay: [Date: Double] = [:]
        for item in activities {
            let day = calendar.startOfDay(for: item.startDate)
            effortByDay[day, default: 0.0] += max(0.0, item.effortScore)
        }

        let fitnessAlpha = 2.0 / 43.0
        let fatigueAlpha = 2.0 / 8.0
        var fitness = 0.0
        var fatigue = 0.0

        var output: [FitnessTrendPoint] = []
        output.reserveCapacity(countDays)

        for offset in stride(from: -(totalSpan - 1), through: 0, by: 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: endDay) else { continue }
            let dailyEffort = effortByDay[day] ?? 0.0
            fitness += fitnessAlpha * (dailyEffort - fitness)
            fatigue += fatigueAlpha * (dailyEffort - fatigue)
            let form = fitness - fatigue

            if offset > -countDays {
                output.append(
                    FitnessTrendPoint(
                        date: day,
                        dailyEffort: dailyEffort,
                        fitness: fitness,
                        fatigue: fatigue,
                        form: form
                    )
                )
            }
        }
        return output
    }

    public static func goalProgress(
        activities: [ActivityStatsInput],
        periodRaw: String,
        metricRaw: String,
        activityTypeFilter: ActivityType?,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Double {
        let component: Calendar.Component = (periodRaw == "monthly") ? .month : .weekOfYear
        guard let interval = calendar.dateInterval(of: component, for: referenceDate) else { return 0.0 }

        let matching = activities.filter { item in
            guard item.startDate >= interval.start && item.startDate < interval.end else { return false }
            if let activityTypeFilter, item.activityType != activityTypeFilter {
                return false
            }
            return true
        }

        if metricRaw == "movingTime" {
            return matching.reduce(0.0) { $0 + $1.movingTime }
        }
        return matching.reduce(0.0) { $0 + $1.distanceMeters }
    }
}
