import SwiftData
import SwiftUI
import TrackerCore

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @Query(sort: \SDActivity.startDate, order: .reverse)
    private var activities: [SDActivity]

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    ContentUnavailableView(
                        "No Activities Yet",
                        systemImage: "figure.run",
                        description: Text("Recorded runs, rides, walks, and hikes will appear here.")
                    )
                } else {
                    List {
                        ForEach(activities) { activity in
                            activityRow(activity)
                        }
                        .onDelete(perform: deleteActivities)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
        }
    }

    @ViewBuilder
    private func activityRow(_ activity: SDActivity) -> some View {
        let unit = settings.unitSystem
        let coords = activity.decodedPreviewCoordinates()

        HStack(spacing: 12) {
            RouteThumbnailBadge(
                coordinates: coords,
                symbolName: activity.activityType.symbolName
            )
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(activity.activityType.displayName)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RunTheme.electricTeal.opacity(0.15))
                        .foregroundStyle(RunTheme.electricTeal)
                        .clipShape(Capsule())
                }

                Text(activity.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Text(RunFormatter.distance(meters: activity.distanceMeters, unit: unit))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                    Text(RunFormatter.duration(seconds: activity.movingTime))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if activity.activityType.prefersSpeedOverPace {
                        Text(RunFormatter.speed(metersPerSecond: activity.averageSpeedMPS, unit: unit))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text(RunFormatter.pace(secondsPerMeter: activity.averagePaceSecondsPerMeter, unit: unit))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteActivities(at offsets: IndexSet) {
        for index in offsets {
            let activity = activities[index]
            TrackFileStore.shared.deleteTrackFile(fileName: activity.trackFileName)
            modelContext.delete(activity)
        }
        try? modelContext.save()
    }
}

struct RouteThumbnailBadge: View {
    let coordinates: [PreviewCoordinate]
    let symbolName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(RunTheme.midnightSlate)

            if coordinates.count >= 2 {
                Canvas { context, size in
                    let lats = coordinates.map(\.latitude)
                    let lons = coordinates.map(\.longitude)
                    guard let minLat = lats.min(),
                          let maxLat = lats.max(),
                          let minLon = lons.min(),
                          let maxLon = lons.max() else { return }

                    let inset: CGFloat = 8
                    let spanLon = max(maxLon - minLon, 1e-6)
                    let spanLat = max(maxLat - minLat, 1e-6)
                    let drawW = max(1, size.width - inset * 2)
                    let drawH = max(1, size.height - inset * 2)
                    let scale = min(drawW / spanLon, drawH / spanLat)
                    let offsetX = (size.width - spanLon * scale) * 0.5
                    let offsetY = (size.height - spanLat * scale) * 0.5

                    var path = Path()
                    for (idx, pt) in coordinates.enumerated() {
                        let x = offsetX + CGFloat(pt.longitude - minLon) * scale
                        let y = size.height - (offsetY + CGFloat(pt.latitude - minLat) * scale)
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    context.stroke(path, with: .color(RunTheme.electricTeal), lineWidth: 2.2)
                }
            } else {
                Image(systemName: symbolName)
                    .font(.title3)
                    .foregroundStyle(RunTheme.electricTeal)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RunTheme.hudBorder.opacity(0.6), lineWidth: 1)
        )
    }
}
