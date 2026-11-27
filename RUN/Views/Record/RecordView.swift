import CoreLocation
import MapKit
import SwiftData
import SwiftUI
import TrackerCore

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings
    @Environment(LocationRecordingService.self) private var recorder
    @Environment(HeartRateMonitorService.self) private var heartRateMonitor
    @Environment(BarometerService.self) private var barometer

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var followUser = true
    @State private var lastCameraUpdateDate: Date?
    @State private var showingFullScreenMap = false
    @State private var showingFinishSheet = false
    @State private var showingDiscardAlert = false
    @State private var showingHeartRateSheet = false
    @State private var finishTitle = ""
    @State private var finishNotes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 14) {
                            topHeaderBar
                            permissionBanner
                            followRouteBanner
                            heartRateSensorBar
                            liveMapCard
                            telemetrySection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }

                    controlsBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                }

                if case let .countdown(remaining) = recorder.state {
                    countdownOverlay(remaining: remaining)
                }
            }
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingFinishSheet) {
                finishActivitySheet
            }
            .sheet(isPresented: $showingHeartRateSheet) {
                heartRateSheet
            }
            .sheet(item: recoverySheetBinding) { item in
                recoveryPromptSheet(pending: item.session)
            }
            .alert("Discard Activity?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    recorder.discard()
                }
                Button("Keep Recording", role: .cancel) {}
            } message: {
                Text("This recording has not been saved and will be permanently removed.")
            }
            .fullScreenCover(isPresented: $showingFullScreenMap) {
                FullScreenRecordMapView {
                    finishTitle = recorder.defaultTitle(for: recorder.selectedActivityType)
                    finishNotes = ""
                    showingFinishSheet = true
                }
            }
            .onChange(of: recorder.latestCoordinate?.latitude) { _, _ in
                guard followUser, let coord = recorder.latestCoordinate else { return }
                let now = Date()
                if TrackMapHelper.shouldThrottleCameraUpdate(lastUpdate: lastCameraUpdateDate, now: now, minimumIntervalSeconds: 1.5) {
                    return
                }
                lastCameraUpdateDate = now
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )
                )
            }
        }
    }

    private var recoverySheetBinding: Binding<RecoverySheetItem?> {
        Binding(
            get: {
                recorder.pendingRecovery.map { RecoverySheetItem(session: $0) }
            },
            set: { newValue in
                if newValue == nil, recorder.pendingRecovery != nil {
                    // Explicit user action buttons handle recover or discard.
                }
            }
        )
    }

    @ViewBuilder
    private var topHeaderBar: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: recorder.selectedActivityType.symbolName)
                        .foregroundStyle(RunTheme.electricTeal)
                    Text(recorder.state.statusLabel)
                        .font(.headline.weight(.bold))
                }

                Spacer()

                gpsQualityBadge
            }

            if recorder.state == .idle {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ActivityType.gpsCases) { type in
                            let selected = recorder.selectedActivityType == type
                            Button {
                                recorder.setActivityType(type)
                            } label: {
                                Label(type.displayName, systemImage: type.symbolName)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selected ? RunTheme.electricTeal : Color.secondary.opacity(0.15))
                                    .foregroundStyle(selected ? RunTheme.midnightSlate : Color.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Activity type \(type.displayName)")
                            .accessibilityIdentifier("record.type.\(type.rawValue)")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var gpsQualityBadge: some View {
        let color = gpsColor
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            if let acc = recorder.latestAccuracyMeters, recorder.state.isActiveSession {
                Text("GPS \(recorder.gpsQuality.displayName) (±\(Int(acc.rounded()))m)")
            } else {
                Text(passiveAuthLabel)
            }
        }
        .font(.caption.monospacedDigit().weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
        .accessibilityLabel("GPS signal status")
    }

    private var passiveAuthLabel: String {
        switch recorder.authorizationStatus {
        case .notDetermined: return "GPS Standby"
        case .denied, .restricted: return "GPS Off"
        case .authorizedAlways, .authorizedWhenInUse:
            return recorder.isReducedAccuracy ? "GPS Reduced" : "GPS Ready"
        @unknown default: return "GPS Ready"
        }
    }

    private var gpsColor: Color {
        if recorder.isPermissionDeniedOrRestricted { return RunTheme.coral }
        if recorder.isReducedAccuracy { return RunTheme.amber }
        guard recorder.state.isActiveSession else {
            return recorder.isAuthorizedForTracking ? RunTheme.emerald : RunTheme.electricTeal
        }
        switch recorder.gpsQuality {
        case .excellent, .good: return RunTheme.emerald
        case .fair: return RunTheme.amber
        case .poor, .lost: return RunTheme.coral
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if recorder.isPermissionDeniedOrRestricted {
            VStack(alignment: .leading, spacing: 8) {
                Label("Location Access Disabled", systemImage: "location.slash.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RunTheme.coral)
                Text("RUN needs While Using the App location permission to record distance, pace, and routes in the background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open iPhone Settings") {
                    recorder.openAppSystemSettings()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(RunTheme.coral)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RunTheme.coral.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if recorder.isReducedAccuracy {
            VStack(alignment: .leading, spacing: 8) {
                Label("Precise Location Is Off", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RunTheme.amber)
                Text("Approximate location reduces GPS accuracy. Enable Precise Location in Settings for accurate routes and splits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button("Request Full Accuracy") {
                        recorder.requestTemporaryFullAccuracy()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    Button("Open Settings") {
                        recorder.openAppSystemSettings()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(RunTheme.amber)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RunTheme.amber.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private var followRouteBanner: some View {
        if let followed = recorder.activeFollowedRoute {
            let isOffRoute = recorder.routeFollowStatus?.isOffRoute == true
            let bannerColor = isOffRoute ? RunTheme.coral : RunTheme.violet
            let detailText: String = {
                guard let status = recorder.routeFollowStatus else {
                    return "Route ready (\(followed.waypoints.count) pts)"
                }
                if status.isOffRoute {
                    return "Off route by \(RunFormatter.elevation(meters: status.distanceOffRouteMeters, unit: settings.unitSystem))"
                }
                return "\(RunFormatter.distance(meters: status.remainingDistanceMeters, unit: settings.unitSystem)) remaining"
            }()

            HStack(spacing: 10) {
                Image(systemName: isOffRoute ? "exclamationmark.triangle.fill" : "point.topleft.down.curvedto.point.bottomright.up")
                    .foregroundStyle(bannerColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(followed.name)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Text(detailText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(isOffRoute ? RunTheme.coral : .secondary)
                }

                Spacer()

                Button {
                    recorder.clearFollowedRoute()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear followed route")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(bannerColor.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var heartRateSensorBar: some View {
        if settings.featureFlags.bleHeartRate {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(heartRateMonitor.connectionState == .connected ? RunTheme.coral : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    if let name = heartRateMonitor.connectedDeviceName,
                       heartRateMonitor.connectionState == .connected {
                        if let bpm = heartRateMonitor.currentBPM {
                            Text("\(name) · \(Int(bpm.rounded())) bpm")
                                .font(.caption.weight(.bold).monospacedDigit())
                        } else {
                            Text("\(name) · Waiting for BPM")
                                .font(.caption.weight(.semibold))
                        }
                    } else {
                        Text("Heart-Rate Strap: \(heartRateMonitor.connectionState.displayLabel)")
                            .font(.caption.weight(.semibold))
                    }
                    Text("Bluetooth 0x180D sensor")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Sensors") {
                    showingHeartRateSheet = true
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(RunTheme.coral)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RunTheme.coral.opacity(0.11))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var liveMapCard: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                UserAnnotation()
                if let followed = recorder.activeFollowedRoute, followed.waypoints.count >= 2 {
                    let guideCoords = followed.waypoints.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    }
                    MapPolyline(coordinates: guideCoords)
                        .stroke(RunTheme.violet.opacity(0.75), style: StrokeStyle(lineWidth: 5, dash: [8, 6]))
                }
                if let first = recorder.routeCoordinates.first {
                    Marker("Start", systemImage: "flag.fill", coordinate: first)
                        .tint(RunTheme.emerald)
                }
                if recorder.routeCoordinates.count >= 2 {
                    let preview = recorder.routeCoordinates.map {
                        PreviewCoordinate(latitude: $0.latitude, longitude: $0.longitude)
                    }
                    let sampled = TrackMapHelper.downsample(preview, maxPoints: 300).map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    }
                    MapPolyline(coordinates: sampled)
                        .stroke(RunTheme.electricTeal, lineWidth: 5)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(RunTheme.hudBorder.opacity(0.45), lineWidth: 1)
            )
            .accessibilityIdentifier("record.map")

            VStack(spacing: 8) {
                Button {
                    showingFullScreenMap = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RunTheme.electricTeal)
                        .padding(10)
                        .background(RunTheme.hudSurface.opacity(0.92))
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .accessibilityLabel("Expand full-screen map")

                Button {
                    followUser.toggle()
                    if followUser {
                        lastCameraUpdateDate = nil
                        cameraPosition = .userLocation(fallback: .automatic)
                    }
                } label: {
                    Image(systemName: followUser ? "location.fill" : "location")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(followUser ? RunTheme.midnightSlate : RunTheme.electricTeal)
                        .padding(10)
                        .background(followUser ? RunTheme.electricTeal : RunTheme.hudSurface.opacity(0.9))
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .accessibilityLabel(followUser ? "Following your location" : "Center on your location")
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private var telemetrySection: some View {
        let unit = settings.unitSystem
        let prefersSpeed = recorder.selectedActivityType.prefersSpeedOverPace

        VStack(spacing: 10) {
            HStack(spacing: 10) {
                metricCard(
                    title: "DISTANCE",
                    value: RunFormatter.distance(meters: recorder.distanceMeters, unit: unit),
                    accent: RunTheme.electricTeal,
                    large: true
                )
                metricCard(
                    title: "MOVING TIME",
                    value: RunFormatter.duration(seconds: recorder.movingTime),
                    accent: .primary,
                    large: true
                )
            }

            HStack(spacing: 10) {
                if prefersSpeed {
                    metricCard(
                        title: "CURRENT SPEED",
                        value: RunFormatter.speed(metersPerSecond: recorder.currentSpeedMPS, unit: unit),
                        accent: RunTheme.emerald,
                        large: false
                    )
                    metricCard(
                        title: "AVG SPEED",
                        value: RunFormatter.speed(metersPerSecond: recorder.averageSpeedMPS, unit: unit),
                        accent: .primary,
                        large: false
                    )
                } else {
                    metricCard(
                        title: "CURRENT PACE",
                        value: RunFormatter.pace(secondsPerMeter: recorder.currentPaceSecondsPerMeter, unit: unit),
                        accent: RunTheme.emerald,
                        large: false
                    )
                    metricCard(
                        title: "AVG PACE",
                        value: RunFormatter.pace(secondsPerMeter: recorder.averagePaceSecondsPerMeter, unit: unit),
                        accent: .primary,
                        large: false
                    )
                }
            }

            HStack(spacing: 10) {
                metricCard(
                    title: "ELAPSED",
                    value: RunFormatter.duration(seconds: recorder.elapsedTime),
                    accent: .secondary,
                    large: false
                )
                let elevTitle = (settings.featureFlags.barometricAltimeter && barometer.isReceivingUpdates)
                    ? "ELEV GAIN (BARO)"
                    : "ELEV GAIN"
                metricCard(
                    title: elevTitle,
                    value: RunFormatter.elevation(meters: recorder.elevationGainMeters, unit: unit),
                    accent: RunTheme.violet,
                    large: false
                )
            }

            if settings.featureFlags.bleHeartRate {
                let hrText = heartRateMonitor.currentBPM.map { "\(Int($0.rounded())) bpm" } ?? "-- bpm"
                metricCard(
                    title: "HEART RATE (BLE)",
                    value: hrText,
                    accent: RunTheme.coral,
                    large: false
                )
            }
        }
    }

    @ViewBuilder
    private func metricCard(title: String, value: String, accent: Color, large: Bool) -> some View {
        let baseFont: Font = large ? .title : .title3
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(baseFont.weight(.bold).monospacedDigit())
                .foregroundStyle(accent)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var controlsBar: some View {
        switch recorder.state {
        case .idle:
            Button {
                recorder.requestStart(settings: settings)
            } label: {
                Label("Start \(recorder.selectedActivityType.displayName)", systemImage: "play.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RunTheme.electricTeal)
                    .foregroundStyle(RunTheme.midnightSlate)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(recorder.isPermissionDeniedOrRestricted)
            .accessibilityIdentifier("record.startButton")

        case .countdown:
            Button("Cancel Countdown", role: .cancel) {
                recorder.cancelCountdown()
            }
            .buttonStyle(.borderedProminent)
            .tint(RunTheme.coral)
            .frame(maxWidth: .infinity)

        case .recording:
            HStack(spacing: 10) {
                Button {
                    recorder.markLap(settings: settings)
                } label: {
                    Label("Lap", systemImage: "flag.fill")
                        .font(.headline.weight(.bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(RunTheme.electricTeal)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel("Mark lap")

                Button {
                    recorder.pauseManually()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RunTheme.amber)
                        .foregroundStyle(RunTheme.midnightSlate)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityIdentifier("record.pauseButton")
            }

        case .manuallyPaused, .autoPaused:
            HStack(spacing: 10) {
                Button {
                    recorder.resumeManually()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RunTheme.emerald)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityIdentifier("record.resumeButton")

                Button {
                    finishTitle = recorder.defaultTitle(for: recorder.selectedActivityType)
                    finishNotes = ""
                    showingFinishSheet = true
                } label: {
                    Label("Finish", systemImage: "checkmark")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RunTheme.electricTeal)
                        .foregroundStyle(RunTheme.midnightSlate)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityIdentifier("record.finishButton")

                Button(role: .destructive) {
                    showingDiscardAlert = true
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.headline.weight(.bold))
                        .padding(15)
                        .background(RunTheme.coral.opacity(0.18))
                        .foregroundStyle(RunTheme.coral)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel("Discard recording")
            }
        }
    }

    @ViewBuilder
    private func countdownOverlay(remaining: Int) -> some View {
        ZStack {
            RunTheme.midnightSlate.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Get Ready")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(RunTheme.electricTeal)

                Text("\(remaining)")
                    .font(.system(size: 112, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)

                HStack(spacing: 16) {
                    Button("Cancel") {
                        recorder.cancelCountdown()
                    }
                    .buttonStyle(.bordered)
                    .tint(RunTheme.coral)

                    Button("Start Now") {
                        recorder.skipCountdown(settings: settings)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RunTheme.electricTeal)
                    .foregroundStyle(RunTheme.midnightSlate)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var finishActivitySheet: some View {
        NavigationStack {
            Form {
                Section("Summary") {
                    LabeledContent("Type", value: recorder.selectedActivityType.displayName)
                    LabeledContent("Distance", value: RunFormatter.distance(meters: recorder.distanceMeters, unit: settings.unitSystem))
                    LabeledContent("Moving Time", value: RunFormatter.duration(seconds: recorder.movingTime))
                    LabeledContent("Elevation Gain", value: RunFormatter.elevation(meters: recorder.elevationGainMeters, unit: settings.unitSystem))
                }

                Section("Details") {
                    TextField("Activity Title", text: $finishTitle)
                    TextField("Notes (optional)", text: $finishNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Save Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingFinishSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        _ = recorder.finish(
                            title: finishTitle,
                            notes: finishNotes,
                            modelContext: modelContext,
                            settings: settings
                        )
                        showingFinishSheet = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recoveryPromptSheet(pending: PendingRecoverySession) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label("Unfinished Activity Found", systemImage: "arrow.clockwise.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(RunTheme.amber)

                Text("RUN saved your GPS points before the previous session ended unexpectedly. Recover and save it to History, or discard it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Type", value: pending.metadata.activityType.displayName)
                    LabeledContent("Started", value: pending.metadata.startDate.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Points", value: "\(pending.points.count)")
                    LabeledContent("Distance", value: RunFormatter.distance(meters: pending.metadata.distanceMeters, unit: settings.unitSystem))
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer()

                Button {
                    _ = recorder.recoverPendingSession(modelContext: modelContext, settings: settings)
                } label: {
                    Text("Recover & Save Activity")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RunTheme.electricTeal)
                        .foregroundStyle(RunTheme.midnightSlate)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button("Discard Unfinished Session", role: .destructive) {
                    recorder.discardPendingRecovery()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .padding()
            .navigationTitle("Session Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var heartRateSheet: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    LabeledContent("Status", value: heartRateMonitor.connectionState.displayLabel)
                    if let name = heartRateMonitor.connectedDeviceName {
                        LabeledContent("Device", value: name)
                    }
                    if let bpm = heartRateMonitor.currentBPM {
                        LabeledContent("Live Heart Rate", value: "\(Int(bpm.rounded())) bpm")
                    }

                    if heartRateMonitor.connectionState == .scanning {
                        Button("Stop Scanning") {
                            heartRateMonitor.stopScanning()
                        }
                    } else {
                        Button("Scan for 0x180D Straps") {
                            heartRateMonitor.startScanning()
                        }
                    }

                    if heartRateMonitor.connectionState == .connected || heartRateMonitor.connectionState == .connecting {
                        Button("Disconnect", role: .destructive) {
                            heartRateMonitor.disconnect()
                        }
                    }
                }

                if heartRateMonitor.connectionState == .unauthorized {
                    Section {
                        Text("Bluetooth access was denied. Enable Bluetooth for RUN in iPhone Settings to pair a chest or arm strap.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open iPhone Settings") {
                            recorder.openAppSystemSettings()
                        }
                    }
                } else if heartRateMonitor.connectionState == .bluetoothOff {
                    Section {
                        Text("Bluetooth is turned off. Turn on Bluetooth in Control Center or iPhone Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Discovered Straps") {
                    if heartRateMonitor.discoveredSensors.isEmpty {
                        Text(heartRateMonitor.connectionState == .scanning ? "Listening for standard Bluetooth Heart Rate Service (0x180D) straps..." : "Tap Scan to discover nearby straps.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(heartRateMonitor.discoveredSensors) { sensor in
                            Button {
                                heartRateMonitor.connect(sensorID: sensor.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sensor.name)
                                            .font(.body.weight(.semibold))
                                        Text("\(sensor.rssi) dBm")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("Connect")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(RunTheme.electricTeal)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Heart-Rate Strap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        heartRateMonitor.stopScanning()
                        showingHeartRateSheet = false
                    }
                }
            }
        }
    }
}

private struct RecoverySheetItem: Identifiable {
    let session: PendingRecoverySession
    var id: UUID { session.metadata.sessionID }
}
