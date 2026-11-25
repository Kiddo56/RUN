import CoreLocation
import Foundation
import Observation
import SwiftData
import TrackerCore
import UIKit

enum RecordingState: Equatable, Sendable {
    case idle
    case countdown(Int)
    case recording
    case manuallyPaused
    case autoPaused

    var isActiveSession: Bool {
        switch self {
        case .recording, .manuallyPaused, .autoPaused:
            return true
        case .idle, .countdown:
            return false
        }
    }

    var statusLabel: String {
        switch self {
        case .idle: return "Ready"
        case .countdown(let sec): return "Starting in \(sec)"
        case .recording: return "Recording"
        case .manuallyPaused: return "Paused"
        case .autoPaused: return "Auto-Paused"
        }
    }
}

struct FollowedRouteSession: Sendable, Equatable {
    let id: UUID
    let name: String
    let waypoints: [RouteWaypoint]
}

@MainActor
@Observable
final class LocationRecordingService: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let fileStore: TrackFileStore
    private let cues = AudioHapticCueService()

    private(set) var state: RecordingState = .idle
    private(set) var selectedActivityType: ActivityType = .run
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var accuracyAuthorization: CLAccuracyAuthorization
    private(set) var pendingRecovery: PendingRecoverySession?

    // Live telemetry
    private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    private(set) var latestCoordinate: CLLocationCoordinate2D?
    private(set) var distanceMeters: Double = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var movingTime: TimeInterval = 0
    private(set) var currentPaceSecondsPerMeter: Double = 0
    private(set) var averagePaceSecondsPerMeter: Double = 0
    private(set) var currentSpeedMPS: Double = 0
    private(set) var averageSpeedMPS: Double = 0
    private(set) var elevationGainMeters: Double = 0
    private(set) var elevationLossMeters: Double = 0
    private(set) var gpsQuality: GPSQuality = .lost
    private(set) var latestAccuracyMeters: Double?
    private(set) var rejectedFixCount: Int = 0
    private(set) var lastSplitCompleted: ActivitySplit?
    private(set) var activeFollowedRoute: FollowedRouteSession?
    private(set) var routeFollowStatus: RouteFollowStatus?

    // Optional external sensor hooks (populated in Phase 5)
    var currentHeartRateProvider: (@MainActor () -> Double?)?
    var currentBarometricAltitudeProvider: (@MainActor () -> Double?)?
    var onSessionStarted: (@MainActor () -> Void)?
    var onSessionEnded: (@MainActor () -> Void)?
    var onGPSAltitudeAvailable: (@MainActor (_ altitude: Double, _ verticalAccuracy: Double) -> Void)?

    private var engine: RecordingSessionEngine?
    private var activeSessionID: UUID?
    private var unpersistedPoints: [TrackPoint] = []
    private var lastFlushDate: Date = .distantPast
    private var lastOffRouteAlertDate: Date = .distantPast
    private var pendingAutoStartAfterAuth = false
    private weak var activeSettings: AppSettingsStore?

    private var backgroundSession: CLBackgroundActivitySession?
    private var locationTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    init(fileStore: TrackFileStore = .shared) {
        self.fileStore = fileStore
        self.authorizationStatus = locationManager.authorizationStatus
        self.accuracyAuthorization = locationManager.accuracyAuthorization
        super.init()
        locationManager.delegate = self
    }

    var isAuthorizedForTracking: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isPermissionDeniedOrRestricted: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var isReducedAccuracy: Bool {
        isAuthorizedForTracking && accuracyAuthorization == .reducedAccuracy
    }

    func setActivityType(_ type: ActivityType) {
        guard state == .idle else { return }
        selectedActivityType = type
    }

    func selectRouteToFollow(_ route: SDSavedRoute) {
        let wps = route.decodedWaypoints()
        guard wps.count >= 2 else { return }
        activeFollowedRoute = FollowedRouteSession(id: route.id, name: route.name, waypoints: wps)
        routeFollowStatus = nil
        lastOffRouteAlertDate = .distantPast
        DiagnosticsLogger.shared.log(.recording, "Selected route to follow: \(route.name) (\(wps.count) pts)")
    }

    func clearFollowedRoute() {
        activeFollowedRoute = nil
        routeFollowStatus = nil
        lastOffRouteAlertDate = .distantPast
    }

    func checkForPendingRecovery() {
        guard !state.isActiveSession else { return }
        if let recovered = fileStore.loadPendingRecovery(), !recovered.points.isEmpty {
            pendingRecovery = recovered
            DiagnosticsLogger.shared.log(
                .recovery,
                "Found unfinished \(recovered.metadata.activityType.displayName) session with \(recovered.points.count) points"
            )
        } else {
            fileStore.clearJournal()
            pendingRecovery = nil
        }
    }

    func recoverPendingSession(modelContext: ModelContext, settings: AppSettingsStore) -> SDActivity? {
        guard let session = pendingRecovery else { return nil }
        let summary = TrackAnalyzer.summarize(
            points: session.points,
            activityType: session.metadata.activityType,
            unitSystem: settings.unitSystem,
            userWeightKg: settings.userWeightKg,
            elevationHysteresisMeters: settings.elevationHysteresisMeters
        )
        let fileName = "\(session.metadata.sessionID.uuidString).trk"
        do {
            try fileStore.saveTrackPoints(session.points, fileName: fileName)
        } catch {
            DiagnosticsLogger.shared.log(.error, "Failed saving recovered track blob: \(error.localizedDescription)")
            return nil
        }

        let activity = SDActivity(
            id: session.metadata.sessionID,
            activityType: session.metadata.activityType,
            startDate: summary.startDate,
            endDate: summary.endDate,
            movingTime: summary.movingTime,
            elapsedTime: summary.elapsedTime,
            distanceMeters: summary.distanceMeters,
            elevationGainMeters: summary.elevationGainMeters,
            elevationLossMeters: summary.elevationLossMeters,
            averageHeartRate: summary.averageHeartRate,
            maxHeartRate: summary.maxHeartRate,
            effortScore: summary.effortScore,
            estimatedCalories: summary.estimatedCalories,
            title: "Recovered \(session.metadata.activityType.displayName)",
            notes: "Recovered from unfinished recording session.",
            source: "recovered",
            trackFileName: fileName,
            splits: summary.splits,
            previewCoordinates: summary.previewCoordinates,
            pointCount: summary.pointCount
        )
        modelContext.insert(activity)
        try? modelContext.save()
        fileStore.clearJournal()
        pendingRecovery = nil
        DiagnosticsLogger.shared.log(.recovery, "Recovered activity \(activity.id) (\(summary.pointCount) pts)")
        return activity
    }

    func discardPendingRecovery() {
        fileStore.clearJournal()
        pendingRecovery = nil
        DiagnosticsLogger.shared.log(.recovery, "Discarded unfinished recording journal")
    }

    func requestStart(settings: AppSettingsStore) {
        activeSettings = settings
        guard state == .idle else { return }

        if authorizationStatus == .notDetermined {
            pendingAutoStartAfterAuth = true
            DiagnosticsLogger.shared.log(.auth, "Requesting When-In-Use location authorization for recording")
            locationManager.requestWhenInUseAuthorization()
            return
        }

        guard isAuthorizedForTracking else {
            DiagnosticsLogger.shared.log(.auth, "Start blocked: location permission is \(authorizationStatus.rawValue)")
            return
        }

        beginCountdown(settings: settings)
    }

    func requestLocationPermissionOnly() {
        if authorizationStatus == .notDetermined {
            DiagnosticsLogger.shared.log(.auth, "User triggered manual location permission request")
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func requestTemporaryFullAccuracy() {
        locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "WorkoutTracking") { [weak self] error in
            Task { @MainActor in
                if let error {
                    DiagnosticsLogger.shared.log(.auth, "Temporary full accuracy error: \(error.localizedDescription)")
                } else if let self {
                    self.accuracyAuthorization = self.locationManager.accuracyAuthorization
                    DiagnosticsLogger.shared.log(.auth, "Accuracy authorization refreshed")
                }
            }
        }
    }

    func openAppSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        state = .idle
        DiagnosticsLogger.shared.log(.recording, "Countdown cancelled")
    }

    func skipCountdown(settings: AppSettingsStore) {
        activeSettings = settings
        countdownTask?.cancel()
        countdownTask = nil
        startLiveSession(settings: settings)
    }

    func pauseManually() {
        guard state == .recording || state == .autoPaused else { return }
        let now = Date()
        engine?.pauseManually(at: now)
        state = .manuallyPaused
        syncTelemetryFromEngine()
        flushPendingPoints(force: true)
        cues.stateChange(hapticsEnabled: activeSettings?.hapticsEnabled ?? true)
        cues.announcePause(auto: false, audioEnabled: activeSettings?.audioCuesEnabled ?? true)
        DiagnosticsLogger.shared.log(.recording, "Manually paused at \(Int(distanceMeters))m")
    }

    func resumeManually() {
        guard state == .manuallyPaused || state == .autoPaused else { return }
        let now = Date()
        engine?.resumeManually(at: now)
        state = .recording
        syncTelemetryFromEngine()
        cues.stateChange(hapticsEnabled: activeSettings?.hapticsEnabled ?? true)
        cues.announceResume(auto: false, audioEnabled: activeSettings?.audioCuesEnabled ?? true)
        DiagnosticsLogger.shared.log(.recording, "Manually resumed")
    }

    func finish(title: String, notes: String, modelContext: ModelContext, settings: AppSettingsStore) -> SDActivity? {
        guard state.isActiveSession, var engine, let sessionID = activeSessionID else { return nil }
        let now = Date()
        flushPendingPoints(force: true)
        let summary = engine.finish(at: now)
        let points = engine.points
        let fileName = "\(sessionID.uuidString).trk"

        do {
            try fileStore.saveTrackPoints(points, fileName: fileName)
        } catch {
            DiagnosticsLogger.shared.log(.error, "Failed writing final track blob: \(error.localizedDescription)")
            return nil
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty ? defaultTitle(for: selectedActivityType, date: summary.startDate) : cleanTitle

        let activity = SDActivity(
            id: sessionID,
            activityType: selectedActivityType,
            startDate: summary.startDate,
            endDate: summary.endDate,
            movingTime: summary.movingTime,
            elapsedTime: summary.elapsedTime,
            distanceMeters: summary.distanceMeters,
            elevationGainMeters: summary.elevationGainMeters,
            elevationLossMeters: summary.elevationLossMeters,
            averageHeartRate: summary.averageHeartRate,
            maxHeartRate: summary.maxHeartRate,
            effortScore: summary.effortScore,
            estimatedCalories: summary.estimatedCalories,
            title: finalTitle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            source: "recorded",
            trackFileName: fileName,
            splits: summary.splits,
            previewCoordinates: summary.previewCoordinates,
            pointCount: summary.pointCount
        )

        assignDefaultGearAndCheckRetirement(for: activity, modelContext: modelContext, unitSystem: settings.unitSystem)
        modelContext.insert(activity)
        try? modelContext.save()

        cues.announceFinish(
            distanceMeters: summary.distanceMeters,
            movingTime: summary.movingTime,
            unitSystem: settings.unitSystem,
            audioEnabled: settings.audioCuesEnabled
        )
        DiagnosticsLogger.shared.log(
            .recording,
            "Finished \(selectedActivityType.displayName): \(Int(summary.distanceMeters))m, \(summary.pointCount) pts"
        )

        stopAllTasksAndResetSession()
        return activity
    }

    func discard() {
        DiagnosticsLogger.shared.log(.recording, "Discarded active recording (\(Int(distanceMeters))m)")
        stopAllTasksAndResetSession()
    }

    func flushForBackgroundTransition() {
        guard state.isActiveSession else { return }
        flushPendingPoints(force: true)
        DiagnosticsLogger.shared.log(.recording, "Flushed active points on background transition")
    }

    func defaultTitle(for type: ActivityType, date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let prefix: String
        switch hour {
        case 5..<12: prefix = "Morning"
        case 12..<17: prefix = "Afternoon"
        case 17..<21: prefix = "Evening"
        default: prefix = "Night"
        }
        return "\(prefix) \(type.displayName)"
    }

    private func assignDefaultGearAndCheckRetirement(
        for activity: SDActivity,
        modelContext: ModelContext,
        unitSystem: UnitSystem
    ) {
        guard let gearList = try? modelContext.fetch(FetchDescriptor<SDGear>()) else { return }
        let matchingGear: SDGear?
        switch activity.activityType {
        case .run, .walk, .hike:
            matchingGear = gearList.first(where: { !$0.isRetired && $0.isDefaultForRun })
        case .ride:
            matchingGear = gearList.first(where: { !$0.isRetired && $0.isDefaultForRide })
        case .other:
            matchingGear = nil
        }

        guard let gear = matchingGear else { return }
        activity.gearID = gear.id

        let existingActivities = (try? modelContext.fetch(FetchDescriptor<SDActivity>())) ?? []
        let loggedDist = existingActivities
            .filter { $0.gearID == gear.id && $0.id != activity.id }
            .reduce(0.0) { $0 + $1.distanceMeters }
        let totalGearDist = gear.initialDistanceMeters + loggedDist + activity.distanceMeters

        if gear.maxDistanceMeters > 0 && totalGearDist >= gear.maxDistanceMeters {
            let gearID = gear.id
            let gearName = gear.name
            let currText = RunFormatter.distance(meters: totalGearDist, unit: unitSystem, decimals: 0)
            let maxText = RunFormatter.distance(meters: gear.maxDistanceMeters, unit: unitSystem, decimals: 0)
            Task {
                await NotificationService.shared.sendGearRetirementAlertIfNeeded(
                    gearID: gearID,
                    gearName: gearName,
                    currentText: currText,
                    maxText: maxText
                )
            }
        }
    }

    private func beginCountdown(settings: AppSettingsStore) {
        countdownTask?.cancel()
        state = .countdown(3)
        cues.countdownTick(hapticsEnabled: settings.hapticsEnabled)

        countdownTask = Task { [weak self] in
            for remaining in [3, 2, 1] {
                guard let self, !Task.isCancelled else { return }
                self.state = .countdown(remaining)
                self.cues.countdownTick(hapticsEnabled: settings.hapticsEnabled)
                try? await Task.sleep(for: .seconds(1))
            }
            guard let self, !Task.isCancelled else { return }
            self.startLiveSession(settings: settings)
        }
    }

    private func startLiveSession(settings: AppSettingsStore) {
        let now = Date()
        let sessionID = UUID()
        self.activeSessionID = sessionID
        self.activeSettings = settings
        self.routeCoordinates = []
        self.latestCoordinate = nil
        self.rejectedFixCount = 0
        self.lastSplitCompleted = nil
        self.unpersistedPoints = []
        self.lastFlushDate = now

        let newEngine = RecordingSessionEngine(
            activityType: selectedActivityType,
            unitSystem: settings.unitSystem,
            startDate: now,
            autoPauseEnabled: settings.autoPauseEnabled,
            maxHorizontalAccuracyMeters: settings.maxHorizontalAccuracyMeters,
            elevationHysteresisMeters: settings.elevationHysteresisMeters,
            userWeightKg: settings.userWeightKg
        )
        self.engine = newEngine
        self.state = .recording
        syncTelemetryFromEngine()

        let meta = RecoveryMetadata(
            sessionID: sessionID,
            activityType: selectedActivityType,
            startDate: now,
            lastFlushDate: now,
            elapsedTime: 0,
            movingTime: 0,
            distanceMeters: 0,
            elevationGainMeters: 0,
            elevationLossMeters: 0
        )
        try? fileStore.startJournal(metadata: meta)

        backgroundSession?.invalidate()
        backgroundSession = CLBackgroundActivitySession()
        DiagnosticsLogger.shared.log(.recording, "Started \(selectedActivityType.displayName) session \(sessionID.uuidString) with CLBackgroundActivitySession")

        cues.countdownGo(hapticsEnabled: settings.hapticsEnabled)
        cues.announceStart(type: selectedActivityType, audioEnabled: settings.audioCuesEnabled)

        onSessionStarted?()
        startLocationUpdatesStream()
        startTickerLoop()
    }

    private func startLocationUpdatesStream() {
        locationTask?.cancel()
        locationTask = Task { [weak self] in
            do {
                let updates = CLLocationUpdate.liveUpdates(.fitness)
                for try await update in updates {
                    guard !Task.isCancelled, let self else { break }
                    if let location = update.location {
                        self.handleIncomingLocation(location)
                    }
                }
            } catch {
                guard self != nil, !Task.isCancelled else { return }
                DiagnosticsLogger.shared.log(.error, "CLLocationUpdate stream error: \(error.localizedDescription)")
            }
        }
    }

    private func startTickerLoop() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { break }
                self.handleTimerTick()
            }
        }
    }

    private func handleTimerTick() {
        guard state.isActiveSession, var currentEngine = engine else { return }
        let now = Date()
        let transition = currentEngine.tick(now: now)
        engine = currentEngine
        handleMovingTransition(transition)
        syncTelemetryFromEngine()

        if now.timeIntervalSince(lastFlushDate) >= 10.0 {
            flushPendingPoints(force: false)
        }
    }

    private func handleIncomingLocation(_ location: CLLocation) {
        guard state.isActiveSession, var currentEngine = engine else { return }
        let now = Date()
        onGPSAltitudeAvailable?(location.altitude, location.verticalAccuracy)
        let baroAlt = currentBarometricAltitudeProvider?()
        let pt = TrackPoint(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: baroAlt ?? location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            speed: location.speed,
            course: location.course,
            heartRate: currentHeartRateProvider?(),
            isPaused: state == .manuallyPaused
        )

        let result = currentEngine.ingest(pt, now: now)
        engine = currentEngine

        switch result.decision {
        case .accept:
            if let lastStored = currentEngine.points.last {
                unpersistedPoints.append(lastStored)
                let coord = CLLocationCoordinate2D(latitude: lastStored.latitude, longitude: lastStored.longitude)
                latestCoordinate = coord
                if state != .manuallyPaused && !currentEngine.isAutoPaused {
                    routeCoordinates.append(coord)
                }
            }
        case .reject(let reason, _):
            rejectedFixCount += 1
            if rejectedFixCount <= 10 || rejectedFixCount % 10 == 0 {
                DiagnosticsLogger.shared.log(.location, "Rejected GPS fix (\(reason.rawValue)), hAcc=\(Int(location.horizontalAccuracy))m")
            }
        }

        handleMovingTransition(result.movingTransition)

        if let split = result.completedSplit, let settings = activeSettings {
            lastSplitCompleted = split
            cues.splitMilestone(hapticsEnabled: settings.hapticsEnabled)
            cues.announceSplit(
                split,
                type: selectedActivityType,
                unitSystem: settings.unitSystem,
                totalDistanceMeters: currentEngine.distanceMeters,
                totalMovingTime: currentEngine.movingTime,
                audioEnabled: settings.audioCuesEnabled
            )
            DiagnosticsLogger.shared.log(.recording, "Completed split #\(split.index)")
        }

        syncTelemetryFromEngine()
        evaluateFollowedRoute(at: location, now: now)
        if unpersistedPoints.count >= 10 || now.timeIntervalSince(lastFlushDate) >= 10.0 {
            flushPendingPoints(force: false)
        }
    }

    private func evaluateFollowedRoute(at location: CLLocation, now: Date) {
        guard let followed = activeFollowedRoute else {
            routeFollowStatus = nil
            return
        }
        let status = RouteNavigationEngine.evaluate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            waypoints: followed.waypoints,
            offRouteThresholdMeters: 50.0
        )
        routeFollowStatus = status

        if status.isOffRoute && now.timeIntervalSince(lastOffRouteAlertDate) >= 30.0 {
            lastOffRouteAlertDate = now
            let unit = activeSettings?.unitSystem ?? .metric
            cues.offRouteAlert(
                distanceMeters: status.distanceOffRouteMeters,
                unitSystem: unit,
                audioEnabled: activeSettings?.audioCuesEnabled ?? true,
                hapticsEnabled: activeSettings?.hapticsEnabled ?? true
            )
            DiagnosticsLogger.shared.log(.location, "Off-route alert: \(Int(status.distanceOffRouteMeters))m from \(followed.name)")
        }
    }

    private func handleMovingTransition(_ transition: MovingTransition) {
        switch transition {
        case .none:
            break
        case .didAutoPause:
            if state == .recording {
                state = .autoPaused
                cues.stateChange(hapticsEnabled: activeSettings?.hapticsEnabled ?? true)
                cues.announcePause(auto: true, audioEnabled: activeSettings?.audioCuesEnabled ?? true)
                DiagnosticsLogger.shared.log(.recording, "Auto-paused")
            }
        case .didAutoResume:
            if state == .autoPaused {
                state = .recording
                cues.stateChange(hapticsEnabled: activeSettings?.hapticsEnabled ?? true)
                cues.announceResume(auto: true, audioEnabled: activeSettings?.audioCuesEnabled ?? true)
                DiagnosticsLogger.shared.log(.recording, "Auto-resumed")
            }
        }
    }

    private func syncTelemetryFromEngine() {
        guard let engine else { return }
        distanceMeters = engine.distanceMeters
        elapsedTime = engine.elapsedTime
        movingTime = engine.movingTime
        currentPaceSecondsPerMeter = engine.currentPaceSecondsPerMeter
        averagePaceSecondsPerMeter = engine.averagePaceSecondsPerMeter
        currentSpeedMPS = engine.currentSpeedMPS
        averageSpeedMPS = engine.averageSpeedMPS
        elevationGainMeters = engine.elevationGainMeters
        elevationLossMeters = engine.elevationLossMeters
        gpsQuality = engine.lastQuality
        latestAccuracyMeters = engine.lastHorizontalAccuracyMeters
    }

    private func flushPendingPoints(force: Bool) {
        guard let sessionID = activeSessionID, let engine else { return }
        let now = Date()
        if !force && unpersistedPoints.isEmpty && now.timeIntervalSince(lastFlushDate) < 10.0 {
            return
        }
        let batch = unpersistedPoints
        unpersistedPoints.removeAll()
        lastFlushDate = now

        let meta = RecoveryMetadata(
            sessionID: sessionID,
            activityType: selectedActivityType,
            startDate: engine.startDate,
            lastFlushDate: now,
            elapsedTime: engine.elapsedTime,
            movingTime: engine.movingTime,
            distanceMeters: engine.distanceMeters,
            elevationGainMeters: engine.elevationGainMeters,
            elevationLossMeters: engine.elevationLossMeters
        )
        try? fileStore.appendJournalPoints(batch, metadata: meta)
    }

    private func stopAllTasksAndResetSession() {
        countdownTask?.cancel()
        countdownTask = nil
        locationTask?.cancel()
        locationTask = nil
        timerTask?.cancel()
        timerTask = nil

        backgroundSession?.invalidate()
        backgroundSession = nil

        onSessionEnded?()
        fileStore.clearJournal()
        engine = nil
        activeSessionID = nil
        unpersistedPoints = []
        state = .idle
        routeCoordinates = []
        latestCoordinate = nil
        distanceMeters = 0
        elapsedTime = 0
        movingTime = 0
        currentPaceSecondsPerMeter = 0
        averagePaceSecondsPerMeter = 0
        currentSpeedMPS = 0
        averageSpeedMPS = 0
        elevationGainMeters = 0
        elevationLossMeters = 0
        rejectedFixCount = 0
        lastSplitCompleted = nil
        routeFollowStatus = nil
        lastOffRouteAlertDate = .distantPast
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        let acc = manager.accuracyAuthorization
        Task { @MainActor in
            self.authorizationStatus = auth
            self.accuracyAuthorization = acc
            DiagnosticsLogger.shared.log(.auth, "Recorder auth changed: status=\(auth.rawValue), acc=\(acc.rawValue)")

            if self.pendingAutoStartAfterAuth {
                self.pendingAutoStartAfterAuth = false
                if self.isAuthorizedForTracking, let settings = self.activeSettings {
                    self.beginCountdown(settings: settings)
                }
            }
        }
    }
}
