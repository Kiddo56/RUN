import Foundation
import SwiftData
import TrackerCore
import UniformTypeIdentifiers

enum DataTransferError: LocalizedError {
    case emptyActivityList
    case insufficientTrackPoints
    case insufficientRouteWaypoints

    var errorDescription: String? {
        switch self {
        case .emptyActivityList:
            return "There are no activities to export."
        case .insufficientTrackPoints:
            return "The GPX file does not contain enough track points."
        case .insufficientRouteWaypoints:
            return "The GPX file does not contain enough waypoints for a route."
        }
    }
}

@MainActor
enum DataTransferService {
    struct RestoreSummary: Sendable, Equatable {
        let activitiesRestored: Int
        let gearRestored: Int
        let goalsRestored: Int
        let routesRestored: Int
        let sectionsRestored: Int
    }

    static var gpxContentTypes: [UTType] {
        var types: [UTType] = []
        if let gpx = UTType(filenameExtension: "gpx") {
            types.append(gpx)
        }
        types.append(.xml)
        return types
    }

    static func exportFullBackup(
        modelContext: ModelContext,
        settings: AppSettingsStore,
        appVersion: String,
        fileStore: TrackFileStore = .shared
    ) throws -> URL {
        let activities = (try? modelContext.fetch(FetchDescriptor<SDActivity>())) ?? []
        let gearItems = (try? modelContext.fetch(FetchDescriptor<SDGear>())) ?? []
        let goals = (try? modelContext.fetch(FetchDescriptor<SDGoal>())) ?? []
        let routes = (try? modelContext.fetch(FetchDescriptor<SDSavedRoute>())) ?? []
        let sections = (try? modelContext.fetch(FetchDescriptor<SDSection>())) ?? []

        var activityRecords: [BackupActivityRecord] = []
        activityRecords.reserveCapacity(activities.count)
        for act in activities {
            let trackURL = fileStore.tracksDirectory.appendingPathComponent(act.trackFileName)
            let blobData: Data
            if let existing = try? Data(contentsOf: trackURL), !existing.isEmpty {
                blobData = existing
            } else {
                blobData = (try? TrackBlobCodec.encode([])) ?? Data()
            }

            activityRecords.append(
                BackupActivityRecord(
                    id: act.id,
                    activityType: act.activityType,
                    startDate: act.startDate,
                    endDate: act.endDate,
                    movingTime: act.movingTime,
                    elapsedTime: act.elapsedTime,
                    distanceMeters: act.distanceMeters,
                    elevationGainMeters: act.elevationGainMeters,
                    elevationLossMeters: act.elevationLossMeters,
                    averageHeartRate: act.averageHeartRate,
                    maxHeartRate: act.maxHeartRate,
                    effortScore: act.effortScore,
                    estimatedCalories: act.estimatedCalories,
                    title: act.title,
                    notes: act.notes,
                    gearID: act.gearID,
                    source: act.source,
                    trackFileName: act.trackFileName,
                    trackBlobData: blobData,
                    splits: act.decodedSplits(),
                    previewCoordinates: act.decodedPreviewCoordinates(),
                    pointCount: act.pointCount
                )
            )
        }

        let gearRecords = gearItems.map {
            BackupGearRecord(
                id: $0.id,
                name: $0.name,
                categoryRaw: $0.categoryRaw,
                brand: $0.brand,
                initialDistanceMeters: $0.initialDistanceMeters,
                maxDistanceMeters: $0.maxDistanceMeters,
                isRetired: $0.isRetired,
                isDefaultForRun: $0.isDefaultForRun,
                isDefaultForRide: $0.isDefaultForRide,
                notes: $0.notes,
                addedDate: $0.addedDate
            )
        }

        let goalRecords = goals.map {
            BackupGoalRecord(
                id: $0.id,
                title: $0.title,
                periodRaw: $0.periodRaw,
                metricRaw: $0.metricRaw,
                targetValue: $0.targetValue,
                activityTypeRaw: $0.activityTypeRaw,
                reminderEnabled: $0.reminderEnabled,
                reminderWeekday: $0.reminderWeekday,
                reminderHour: $0.reminderHour,
                createdAt: $0.createdAt
            )
        }

        let routeRecords = routes.map {
            BackupRouteRecord(
                id: $0.id,
                name: $0.name,
                notes: $0.notes,
                createdAt: $0.createdAt,
                distanceMeters: $0.distanceMeters,
                elevationGainMeters: $0.elevationGainMeters,
                source: $0.source,
                waypoints: $0.decodedWaypoints()
            )
        }

        let sectionRecords = sections.map {
            BackupSectionRecord(
                id: $0.id,
                name: $0.name,
                activityTypeRaw: $0.activityTypeRaw,
                startLatitude: $0.startLatitude,
                startLongitude: $0.startLongitude,
                endLatitude: $0.endLatitude,
                endLongitude: $0.endLongitude,
                expectedBearing: $0.expectedBearing,
                distanceMeters: $0.distanceMeters,
                corridorMeters: $0.corridorMeters,
                createdAt: $0.createdAt
            )
        }

        let backupSettings = BackupSettings(
            unitSystem: settings.unitSystem,
            featureFlags: settings.featureFlags,
            autoPauseEnabled: settings.autoPauseEnabled,
            audioCuesEnabled: settings.audioCuesEnabled,
            hapticsEnabled: settings.hapticsEnabled,
            maxHorizontalAccuracyMeters: settings.maxHorizontalAccuracyMeters,
            elevationHysteresisMeters: settings.elevationHysteresisMeters,
            userWeightKg: settings.userWeightKg,
            privacyHideRadiusMeters: settings.privacyHideRadiusMeters
        )

        let envelope = BackupEnvelope(
            schemaVersion: BackupEnvelope.currentSchemaVersion,
            exportedAt: Date(),
            appVersion: appVersion,
            settings: backupSettings,
            activities: activityRecords,
            gear: gearRecords,
            goals: goalRecords,
            routes: routeRecords,
            sections: sectionRecords
        )

        let data = try BackupCodec.encode(envelope)
        let dateTag = filenameDateTag()
        let outURL = FileManager.default.temporaryDirectory.appendingPathComponent("RUN-Backup-v1-\(dateTag).json")
        try data.write(to: outURL, options: .atomic)
        settings.lastBackupDate = Date()
        DiagnosticsLogger.shared.log(.backup, "Exported full backup (\(activityRecords.count) activities, \(data.count) bytes)")
        return outURL
    }

    static func restoreFullBackup(
        from url: URL,
        modelContext: ModelContext,
        settings: AppSettingsStore,
        replaceExisting: Bool,
        fileStore: TrackFileStore = .shared
    ) throws -> RestoreSummary {
        let data = try readSecurityScopedData(from: url)
        return try restoreFullBackup(
            data: data,
            modelContext: modelContext,
            settings: settings,
            replaceExisting: replaceExisting,
            fileStore: fileStore
        )
    }

    static func restoreFullBackup(
        data: Data,
        modelContext: ModelContext,
        settings: AppSettingsStore,
        replaceExisting: Bool,
        fileStore: TrackFileStore = .shared
    ) throws -> RestoreSummary {
        let envelope = try BackupCodec.decode(data)

        if replaceExisting {
            let oldActivities = (try? modelContext.fetch(FetchDescriptor<SDActivity>())) ?? []
            for act in oldActivities {
                fileStore.deleteTrackFile(fileName: act.trackFileName)
                modelContext.delete(act)
            }
            for item in ((try? modelContext.fetch(FetchDescriptor<SDGear>())) ?? []) { modelContext.delete(item) }
            for item in ((try? modelContext.fetch(FetchDescriptor<SDGoal>())) ?? []) { modelContext.delete(item) }
            for item in ((try? modelContext.fetch(FetchDescriptor<SDSavedRoute>())) ?? []) { modelContext.delete(item) }
            for item in ((try? modelContext.fetch(FetchDescriptor<SDSection>())) ?? []) { modelContext.delete(item) }
            try? modelContext.save()
        }

        let existingActivityIDs = Set(((try? modelContext.fetch(FetchDescriptor<SDActivity>())) ?? []).map(\.id))
        let existingGearIDs = Set(((try? modelContext.fetch(FetchDescriptor<SDGear>())) ?? []).map(\.id))
        let existingGoalIDs = Set(((try? modelContext.fetch(FetchDescriptor<SDGoal>())) ?? []).map(\.id))
        let existingRouteIDs = Set(((try? modelContext.fetch(FetchDescriptor<SDSavedRoute>())) ?? []).map(\.id))
        let existingSectionIDs = Set(((try? modelContext.fetch(FetchDescriptor<SDSection>())) ?? []).map(\.id))

        var actCount = 0
        for rec in envelope.activities where !existingActivityIDs.contains(rec.id) {
            if !rec.trackBlobData.isEmpty {
                let decodedPoints = (try? TrackBlobCodec.decode(rec.trackBlobData)) ?? []
                try? fileStore.saveTrackPoints(decodedPoints, fileName: rec.trackFileName)
            }
            let act = SDActivity(
                id: rec.id,
                activityType: rec.activityType,
                startDate: rec.startDate,
                endDate: rec.endDate,
                movingTime: rec.movingTime,
                elapsedTime: rec.elapsedTime,
                distanceMeters: rec.distanceMeters,
                elevationGainMeters: rec.elevationGainMeters,
                elevationLossMeters: rec.elevationLossMeters,
                averageHeartRate: rec.averageHeartRate,
                maxHeartRate: rec.maxHeartRate,
                effortScore: rec.effortScore,
                estimatedCalories: rec.estimatedCalories,
                title: rec.title,
                notes: rec.notes,
                gearID: rec.gearID,
                source: rec.source,
                trackFileName: rec.trackFileName,
                splits: rec.splits,
                previewCoordinates: rec.previewCoordinates,
                pointCount: rec.pointCount
            )
            modelContext.insert(act)
            actCount += 1
        }

        var gearCount = 0
        for rec in envelope.gear where !existingGearIDs.contains(rec.id) {
            let gear = SDGear(
                id: rec.id,
                name: rec.name,
                categoryRaw: rec.categoryRaw,
                brand: rec.brand,
                initialDistanceMeters: rec.initialDistanceMeters,
                maxDistanceMeters: rec.maxDistanceMeters,
                isRetired: rec.isRetired,
                isDefaultForRun: rec.isDefaultForRun,
                isDefaultForRide: rec.isDefaultForRide,
                notes: rec.notes,
                addedDate: rec.addedDate
            )
            modelContext.insert(gear)
            gearCount += 1
        }

        var goalCount = 0
        for rec in envelope.goals where !existingGoalIDs.contains(rec.id) {
            let goal = SDGoal(
                id: rec.id,
                title: rec.title,
                periodRaw: rec.periodRaw,
                metricRaw: rec.metricRaw,
                targetValue: rec.targetValue,
                activityTypeRaw: rec.activityTypeRaw,
                reminderEnabled: rec.reminderEnabled,
                reminderWeekday: rec.reminderWeekday,
                reminderHour: rec.reminderHour,
                createdAt: rec.createdAt
            )
            modelContext.insert(goal)
            goalCount += 1
        }

        var routeCount = 0
        for rec in envelope.routes where !existingRouteIDs.contains(rec.id) {
            let waypointsData = (try? JSONEncoder().encode(rec.waypoints)) ?? Data()
            let route = SDSavedRoute(
                id: rec.id,
                name: rec.name,
                notes: rec.notes,
                createdAt: rec.createdAt,
                distanceMeters: rec.distanceMeters,
                elevationGainMeters: rec.elevationGainMeters,
                source: rec.source,
                waypointsData: waypointsData
            )
            modelContext.insert(route)
            routeCount += 1
        }

        var sectionCount = 0
        for rec in envelope.sections where !existingSectionIDs.contains(rec.id) {
            let section = SDSection(
                id: rec.id,
                name: rec.name,
                activityTypeRaw: rec.activityTypeRaw,
                startLatitude: rec.startLatitude,
                startLongitude: rec.startLongitude,
                endLatitude: rec.endLatitude,
                endLongitude: rec.endLongitude,
                expectedBearing: rec.expectedBearing,
                distanceMeters: rec.distanceMeters,
                corridorMeters: rec.corridorMeters,
                createdAt: rec.createdAt
            )
            modelContext.insert(section)
            sectionCount += 1
        }

        settings.unitSystem = envelope.settings.unitSystem
        settings.featureFlags = envelope.settings.featureFlags
        settings.autoPauseEnabled = envelope.settings.autoPauseEnabled
        settings.audioCuesEnabled = envelope.settings.audioCuesEnabled
        settings.hapticsEnabled = envelope.settings.hapticsEnabled
        settings.maxHorizontalAccuracyMeters = envelope.settings.maxHorizontalAccuracyMeters
        settings.elevationHysteresisMeters = envelope.settings.elevationHysteresisMeters
        settings.userWeightKg = envelope.settings.userWeightKg
        settings.privacyHideRadiusMeters = envelope.settings.privacyHideRadiusMeters
        settings.lastBackupDate = Date()

        try modelContext.save()
        DiagnosticsLogger.shared.log(
            .backup,
            "Restored backup: \(actCount) activities, \(gearCount) gear, \(goalCount) goals, \(routeCount) routes"
        )
        return RestoreSummary(
            activitiesRestored: actCount,
            gearRestored: gearCount,
            goalsRestored: goalCount,
            routesRestored: routeCount,
            sectionsRestored: sectionCount
        )
    }

    static func exportSingleGPX(activity: SDActivity, fileStore: TrackFileStore = .shared) throws -> URL {
        let points = try fileStore.loadTrackPoints(fileName: activity.trackFileName)
        let data = GPXCodec.exportActivity(
            title: activity.title,
            activityType: activity.activityType,
            startDate: activity.startDate,
            points: points
        )
        let fileName = "\(sanitizeFileName(activity.title)).gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func exportRouteGPX(route: SDSavedRoute) throws -> URL {
        let waypoints = route.decodedWaypoints()
        let data = GPXCodec.exportRoute(name: route.name, waypoints: waypoints)
        let fileName = "\(sanitizeFileName(route.name))-route.gpx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func exportBulkGPXZip(activities: [SDActivity], fileStore: TrackFileStore = .shared) throws -> URL {
        guard !activities.isEmpty else { throw DataTransferError.emptyActivityList }
        var entries: [ZipEntry] = []
        entries.reserveCapacity(activities.count)
        for (idx, act) in activities.enumerated() {
            let pts = (try? fileStore.loadTrackPoints(fileName: act.trackFileName)) ?? []
            let gpxData = GPXCodec.exportActivity(
                title: act.title,
                activityType: act.activityType,
                startDate: act.startDate,
                points: pts
            )
            let name = String(format: "%03d_%@.gpx", idx + 1, sanitizeFileName(act.title))
            entries.append(ZipEntry(fileName: name, data: gpxData))
        }
        let zipData = PureZipWriter.createArchive(entries: entries)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RUN-GPX-Export-\(filenameDateTag()).zip")
        try zipData.write(to: url, options: .atomic)
        DiagnosticsLogger.shared.log(.backup, "Exported bulk GPX ZIP (\(entries.count) tracks)")
        return url
    }

    static func exportCSVSummary(
        activities: [SDActivity],
        gearList: [SDGear],
        unitSystem: UnitSystem
    ) throws -> URL {
        guard !activities.isEmpty else { throw DataTransferError.emptyActivityList }
        let gearNames = Dictionary(uniqueKeysWithValues: gearList.map { ($0.id, $0.name) })
        let rows = activities.map { act in
            CSVActivityRow(
                id: act.id,
                startDate: act.startDate,
                title: act.title,
                activityType: act.activityType,
                distanceMeters: act.distanceMeters,
                movingTime: act.movingTime,
                elapsedTime: act.elapsedTime,
                elevationGainMeters: act.elevationGainMeters,
                elevationLossMeters: act.elevationLossMeters,
                averageHeartRate: act.averageHeartRate,
                maxHeartRate: act.maxHeartRate,
                effortScore: act.effortScore,
                estimatedCalories: act.estimatedCalories,
                gearName: act.gearID.flatMap { gearNames[$0] },
                source: act.source,
                notes: act.notes
            )
        }
        let csvData = CSVExporter.export(rows: rows, unitSystem: unitSystem)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RUN-Summary-\(filenameDateTag()).csv")
        try csvData.write(to: url, options: .atomic)
        DiagnosticsLogger.shared.log(.backup, "Exported CSV summary (\(rows.count) rows)")
        return url
    }

    static func importGPXAsActivity(
        from url: URL,
        modelContext: ModelContext,
        settings: AppSettingsStore,
        fileStore: TrackFileStore = .shared
    ) throws -> SDActivity {
        let data = try readSecurityScopedData(from: url)
        return try importGPXAsActivity(
            data: data,
            fallbackName: url.deletingPathExtension().lastPathComponent,
            modelContext: modelContext,
            settings: settings,
            fileStore: fileStore
        )
    }

    static func importGPXAsActivity(
        data: Data,
        fallbackName: String,
        modelContext: ModelContext,
        settings: AppSettingsStore,
        fileStore: TrackFileStore = .shared
    ) throws -> SDActivity {
        let doc = try GPXCodec.parse(data: data)
        guard doc.points.count >= 2 else {
            throw DataTransferError.insufficientTrackPoints
        }

        let summary = TrackAnalyzer.summarize(
            points: doc.points,
            activityType: doc.activityType,
            unitSystem: settings.unitSystem,
            userWeightKg: settings.userWeightKg,
            elevationHysteresisMeters: settings.elevationHysteresisMeters
        )

        let id = UUID()
        let fileName = "\(id.uuidString).trk"
        try fileStore.saveTrackPoints(doc.points, fileName: fileName)

        let title = (doc.name?.isEmpty == false) ? doc.name! : (fallbackName.isEmpty ? "Imported \(doc.activityType.displayName)" : fallbackName)
        let activity = SDActivity(
            id: id,
            activityType: doc.activityType,
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
            title: title,
            source: "gpx_import",
            trackFileName: fileName,
            splits: summary.splits,
            previewCoordinates: summary.previewCoordinates,
            pointCount: summary.pointCount
        )
        modelContext.insert(activity)
        try modelContext.save()
        DiagnosticsLogger.shared.log(.backup, "Imported GPX activity '\(title)' (\(doc.points.count) pts)")
        return activity
    }

    static func importGPXAsRoute(from url: URL, modelContext: ModelContext) throws -> SDSavedRoute {
        let data = try readSecurityScopedData(from: url)
        return try importGPXAsRoute(
            data: data,
            fallbackName: url.deletingPathExtension().lastPathComponent,
            modelContext: modelContext
        )
    }

    static func importGPXAsRoute(
        data: Data,
        fallbackName: String,
        modelContext: ModelContext
    ) throws -> SDSavedRoute {
        let doc = try GPXCodec.parse(data: data)
        guard doc.routeWaypoints.count >= 2 else {
            throw DataTransferError.insufficientRouteWaypoints
        }

        let totalDist = RouteNavigationEngine.totalDistanceMeters(waypoints: doc.routeWaypoints)
        let routeName = (doc.name?.isEmpty == false) ? doc.name! : (fallbackName.isEmpty ? "Imported Route" : fallbackName)
        let route = SDSavedRoute(
            name: routeName,
            distanceMeters: totalDist,
            elevationGainMeters: 0,
            source: "gpx_import"
        )
        route.updateWaypoints(doc.routeWaypoints)
        modelContext.insert(route)
        try modelContext.save()
        DiagnosticsLogger.shared.log(.backup, "Imported GPX route '\(routeName)' (\(doc.routeWaypoints.count) waypoints)")
        return route
    }

    private static func readSecurityScopedData(from url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }

    private static func sanitizeFileName(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let collapsed = String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return collapsed.isEmpty ? "activity" : String(collapsed.prefix(48))
    }

    private static func filenameDateTag() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
