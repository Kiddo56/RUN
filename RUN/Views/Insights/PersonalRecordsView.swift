import SwiftData
import SwiftUI
import TrackerCore

struct PersonalRecordsView: View {
    @Environment(AppSettingsStore.self) private var settings
    @Query(sort: \SDActivity.startDate, order: .reverse) private var activities: [SDActivity]

    @State private var records: [PersonalRecord] = []
    @State private var isScanning = false

    var body: some View {
        Group {
            if isScanning && records.isEmpty {
                ProgressView("Scanning personal records…")
            } else if records.isEmpty {
                ContentUnavailableView(
                    "No Personal Records Yet",
                    systemImage: "trophy",
                    description: Text("Record or import activities to compute your fastest splits, longest distance, and biggest climb.")
                )
            } else {
                List {
                    ForEach(records) { record in
                        if let targetActivity = activities.first(where: { $0.id == record.activityID }) {
                            NavigationLink(destination: ActivityDetailView(activity: targetActivity)) {
                                recordRow(record)
                            }
                        } else {
                            recordRow(record)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Personal Records")
        .task(id: activities.count) {
            await scanRecords()
        }
    }

    @ViewBuilder
    private func recordRow(_ record: PersonalRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: record.category))
                .font(.title3)
                .foregroundStyle(RunTheme.emerald)
                .frame(width: 34, height: 34)
                .background(RunTheme.emerald.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(record.category.displayName)
                    .font(.headline)
                Text("\(record.activityTitle) · \(record.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formattedValue(for: record))
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(RunTheme.electricTeal)
        }
        .padding(.vertical, 3)
    }

    private func formattedValue(for record: PersonalRecord) -> String {
        switch record.category {
        case .longestDistance:
            return RunFormatter.distance(meters: record.value, unit: settings.unitSystem)
        case .biggestClimb:
            return RunFormatter.elevation(meters: record.value, unit: settings.unitSystem)
        default:
            return RunFormatter.duration(seconds: record.value)
        }
    }

    private func iconName(for category: RecordCategory) -> String {
        switch category {
        case .longestDistance: return "point.topleft.down.curvedto.point.bottomright.up"
        case .biggestClimb: return "mountain.2.fill"
        default: return "stopwatch.fill"
        }
    }

    private func scanRecords() async {
        isScanning = true
        defer { isScanning = false }

        let workItems: [(ActivityStatsInput, String)] = activities.map { act in
            let input = ActivityStatsInput(
                id: act.id,
                title: act.title,
                activityType: act.activityType,
                startDate: act.startDate,
                movingTime: act.movingTime,
                distanceMeters: act.distanceMeters,
                elevationGainMeters: act.elevationGainMeters,
                effortScore: act.effortScore,
                estimatedCalories: act.estimatedCalories,
                gearID: act.gearID
            )
            return (input, act.trackFileName)
        }

        let computed = await Task.detached(priority: .userInitiated) {
            let store = TrackFileStore.shared
            var pairs: [(input: ActivityStatsInput, points: [TrackPoint])] = []
            pairs.reserveCapacity(workItems.count)
            for (input, fileName) in workItems {
                let pts = (try? store.loadTrackPoints(fileName: fileName)) ?? []
                pairs.append((input: input, points: pts))
            }
            return PersonalRecordScanner.scanAll(activities: pairs)
        }.value

        records = computed
    }
}
