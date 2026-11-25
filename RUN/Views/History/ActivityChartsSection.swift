import Charts
import SwiftUI
import TrackerCore

struct ActivityChartsSection: View {
    let samples: [TrackChartSample]
    let activityType: ActivityType
    let unitSystem: UnitSystem
    @Binding var scrubbedDistanceUnit: Double?
    let selectedSample: TrackChartSample?

    private var hasHeartRate: Bool {
        samples.contains { ($0.heartRate ?? 0) > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Telemetry Charts")
                    .font(.headline)
                Spacer()
                if scrubbedDistanceUnit != nil {
                    Button("Clear Scrub") {
                        scrubbedDistanceUnit = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RunTheme.electricTeal)
                } else {
                    Text("Drag chart to inspect map")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let selected = selectedSample {
                scrubReadoutBar(sample: selected)
            }

            elevationChartCard
            rateChartCard
            if hasHeartRate {
                heartRateChartCard
            }
        }
    }

    @ViewBuilder
    private func scrubReadoutBar(sample: TrackChartSample) -> some View {
        HStack(spacing: 12) {
            readoutItem(
                label: "DIST",
                value: RunFormatter.distance(meters: sample.distanceMeters, unit: unitSystem)
            )
            readoutItem(
                label: "ELEV",
                value: RunFormatter.elevation(meters: sample.altitudeMeters, unit: unitSystem)
            )
            if activityType.prefersSpeedOverPace {
                readoutItem(
                    label: "SPEED",
                    value: RunFormatter.speed(metersPerSecond: sample.speedMPS, unit: unitSystem)
                )
            } else {
                let secPerM = sample.speedMPS > 0.2 ? (1.0 / sample.speedMPS) : 0
                readoutItem(
                    label: "PACE",
                    value: RunFormatter.pace(secondsPerMeter: secPerM, unit: unitSystem)
                )
            }
            if let hr = sample.heartRate {
                readoutItem(label: "HR", value: "\(Int(hr.rounded())) bpm")
            }
        }
        .padding(10)
        .background(RunTheme.hudSurface)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func readoutItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(RunTheme.electricTeal)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var elevationChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Elevation (\(unitSystem.elevationUnitLabel))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RunTheme.violet)

            Chart(samples) { sample in
                AreaMark(
                    x: .value("Distance", sample.distanceInDisplayUnit(unitSystem)),
                    y: .value("Elevation", displayElevation(sample.altitudeMeters))
                )
                .foregroundStyle(RunTheme.violet.opacity(0.22))

                LineMark(
                    x: .value("Distance", sample.distanceInDisplayUnit(unitSystem)),
                    y: .value("Elevation", displayElevation(sample.altitudeMeters))
                )
                .foregroundStyle(RunTheme.violet)
                .lineStyle(StrokeStyle(lineWidth: 2))

                if let selectedSample {
                    RuleMark(x: .value("Selected", selectedSample.distanceInDisplayUnit(unitSystem)))
                        .foregroundStyle(RunTheme.amber)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxisLabel(unitSystem.distanceUnitLabel)
            .chartXSelection(value: $scrubbedDistanceUnit)
            .frame(height: 150)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var rateChartCard: some View {
        let prefersSpeed = activityType.prefersSpeedOverPace
        let title = prefersSpeed
            ? "Speed (\(unitSystem.speedUnitLabel))"
            : "Pace (min \(unitSystem.paceUnitLabel))"
        let plottedSamples = prefersSpeed ? samples : samples.filter { $0.paceMinutesPerUnit > 0 }

        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RunTheme.electricTeal)

            if plottedSamples.isEmpty {
                Text("No movement rate samples available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(plottedSamples) { sample in
                    LineMark(
                        x: .value("Distance", sample.distanceInDisplayUnit(unitSystem)),
                        y: .value(prefersSpeed ? "Speed" : "Pace", prefersSpeed ? sample.speedInDisplayUnit : sample.paceMinutesPerUnit)
                    )
                    .foregroundStyle(RunTheme.electricTeal)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    if let selectedSample {
                        RuleMark(x: .value("Selected", selectedSample.distanceInDisplayUnit(unitSystem)))
                            .foregroundStyle(RunTheme.amber)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxisLabel(unitSystem.distanceUnitLabel)
                .chartXSelection(value: $scrubbedDistanceUnit)
                .frame(height: 150)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var heartRateChartCard: some View {
        let hrSamples = samples.filter { ($0.heartRate ?? 0) > 0 }

        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate (bpm)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RunTheme.coral)

            Chart(hrSamples) { sample in
                LineMark(
                    x: .value("Distance", sample.distanceInDisplayUnit(unitSystem)),
                    y: .value("BPM", sample.heartRate ?? 0)
                )
                .foregroundStyle(RunTheme.coral)
                .lineStyle(StrokeStyle(lineWidth: 2))

                if let selectedSample {
                    RuleMark(x: .value("Selected", selectedSample.distanceInDisplayUnit(unitSystem)))
                        .foregroundStyle(RunTheme.amber)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxisLabel(unitSystem.distanceUnitLabel)
            .chartXSelection(value: $scrubbedDistanceUnit)
            .frame(height: 140)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func displayElevation(_ meters: Double) -> Double {
        switch unitSystem {
        case .metric: return meters
        case .imperial: return meters * 3.2808398950131
        }
    }
}
