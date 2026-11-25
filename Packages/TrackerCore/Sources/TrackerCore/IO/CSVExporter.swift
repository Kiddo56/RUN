import Foundation

public struct CSVActivityRow: Sendable, Equatable {
    public let id: UUID
    public let startDate: Date
    public let title: String
    public let activityType: ActivityType
    public let distanceMeters: Double
    public let movingTime: TimeInterval
    public let elapsedTime: TimeInterval
    public let elevationGainMeters: Double
    public let elevationLossMeters: Double
    public let averageHeartRate: Double?
    public let maxHeartRate: Double?
    public let effortScore: Double
    public let estimatedCalories: Double
    public let gearName: String?
    public let source: String
    public let notes: String

    public init(
        id: UUID,
        startDate: Date,
        title: String,
        activityType: ActivityType,
        distanceMeters: Double,
        movingTime: TimeInterval,
        elapsedTime: TimeInterval,
        elevationGainMeters: Double,
        elevationLossMeters: Double,
        averageHeartRate: Double?,
        maxHeartRate: Double?,
        effortScore: Double,
        estimatedCalories: Double,
        gearName: String?,
        source: String,
        notes: String
    ) {
        self.id = id
        self.startDate = startDate
        self.title = title
        self.activityType = activityType
        self.distanceMeters = distanceMeters
        self.movingTime = movingTime
        self.elapsedTime = elapsedTime
        self.elevationGainMeters = elevationGainMeters
        self.elevationLossMeters = elevationLossMeters
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.effortScore = effortScore
        self.estimatedCalories = estimatedCalories
        self.gearName = gearName
        self.source = source
        self.notes = notes
    }
}

public enum CSVExporter {
    public static func export(rows: [CSVActivityRow], unitSystem: UnitSystem) -> Data {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let distUnit = unitSystem.distanceUnitLabel
        let elevUnit = unitSystem.elevationUnitLabel
        let rateLabel = "AvgPaceOrSpeed"

        var lines: [String] = [
            "ID,StartDate,Title,Type,Distance(\(distUnit)),MovingTime(s),ElapsedTime(s),\(rateLabel),ElevGain(\(elevUnit)),ElevLoss(\(elevUnit)),AvgHR,MaxHR,EffortScore,EstimatedCalories(kcal),Gear,Source,Notes"
        ]

        for row in rows {
            let distVal = String(format: "%.3f", RunFormatter.distanceValue(meters: row.distanceMeters, unit: unitSystem))
            let elevGainVal: String
            let elevLossVal: String
            switch unitSystem {
            case .metric:
                elevGainVal = String(format: "%.1f", row.elevationGainMeters)
                elevLossVal = String(format: "%.1f", row.elevationLossMeters)
            case .imperial:
                elevGainVal = String(format: "%.1f", row.elevationGainMeters * 3.2808398950131)
                elevLossVal = String(format: "%.1f", row.elevationLossMeters * 3.2808398950131)
            }

            let rateStr: String
            if row.activityType.prefersSpeedOverPace {
                let speedMPS = row.movingTime > 0 ? (row.distanceMeters / row.movingTime) : 0
                rateStr = RunFormatter.speed(metersPerSecond: speedMPS, unit: unitSystem)
            } else {
                let paceSPM = (row.distanceMeters > 0 && row.movingTime > 0) ? (row.movingTime / row.distanceMeters) : 0
                rateStr = RunFormatter.pace(secondsPerMeter: paceSPM, unit: unitSystem)
            }

            let fields: [String] = [
                row.id.uuidString,
                iso.string(from: row.startDate),
                row.title,
                row.activityType.displayName,
                distVal,
                String(format: "%.1f", row.movingTime),
                String(format: "%.1f", row.elapsedTime),
                rateStr,
                elevGainVal,
                elevLossVal,
                row.averageHeartRate.map { String(format: "%.0f", $0) } ?? "",
                row.maxHeartRate.map { String(format: "%.0f", $0) } ?? "",
                String(format: "%.1f", row.effortScore),
                String(format: "%.0f", row.estimatedCalories),
                row.gearName ?? "",
                row.source,
                row.notes
            ]
            lines.append(fields.map(escapeCSV).joined(separator: ","))
        }

        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let doubled = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return value
    }
}
