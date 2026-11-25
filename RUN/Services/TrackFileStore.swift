import Foundation
import TrackerCore

struct RecoveryMetadata: Codable, Sendable, Equatable {
    let sessionID: UUID
    let activityType: ActivityType
    let startDate: Date
    var lastFlushDate: Date
    var elapsedTime: TimeInterval
    var movingTime: TimeInterval
    var distanceMeters: Double
    var elevationGainMeters: Double
    var elevationLossMeters: Double
}

struct PendingRecoverySession: Sendable, Equatable {
    let metadata: RecoveryMetadata
    let points: [TrackPoint]
}

final class TrackFileStore: Sendable {
    static let shared = TrackFileStore()

    let tracksDirectory: URL
    let recoveryDirectory: URL

    private var metadataURL: URL {
        recoveryDirectory.appendingPathComponent("active_metadata.json")
    }

    private var journalURL: URL {
        recoveryDirectory.appendingPathComponent("active_points.jsonl")
    }

    init(baseDirectory: URL? = nil) {
        let root: URL
        if let baseDirectory {
            root = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            root = appSupport.appendingPathComponent("RUNData", isDirectory: true)
        }
        self.tracksDirectory = root.appendingPathComponent("Tracks", isDirectory: true)
        self.recoveryDirectory = root.appendingPathComponent("Recovery", isDirectory: true)
    }

    func saveTrackPoints(_ points: [TrackPoint], fileName: String) throws {
        try FileManager.default.createDirectory(at: tracksDirectory, withIntermediateDirectories: true)
        let data = try TrackBlobCodec.encode(points)
        let target = tracksDirectory.appendingPathComponent(fileName)
        try data.write(to: target, options: .atomic)
    }

    func loadTrackPoints(fileName: String) throws -> [TrackPoint] {
        let target = tracksDirectory.appendingPathComponent(fileName)
        let data = try Data(contentsOf: target)
        return try TrackBlobCodec.decode(data)
    }

    func deleteTrackFile(fileName: String) {
        let target = tracksDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: target)
    }

    func startJournal(metadata: RecoveryMetadata) throws {
        try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: journalURL.path) {
            try FileManager.default.removeItem(at: journalURL)
        }
        _ = FileManager.default.createFile(atPath: journalURL.path, contents: Data())
        try writeRecoveryMetadata(metadata)
    }

    func appendJournalPoints(_ points: [TrackPoint], metadata: RecoveryMetadata) throws {
        try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
        if !points.isEmpty {
            let chunk = JournalLineCodec.encodeBatch(points)
            if FileManager.default.fileExists(atPath: journalURL.path) {
                let handle = try FileHandle(forWritingTo: journalURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: chunk)
            } else {
                try chunk.write(to: journalURL, options: .atomic)
            }
        }
        try writeRecoveryMetadata(metadata)
    }

    func loadPendingRecovery() -> PendingRecoverySession? {
        guard FileManager.default.fileExists(atPath: metadataURL.path),
              let metaData = try? Data(contentsOf: metadataURL) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let metadata = try? decoder.decode(RecoveryMetadata.self, from: metaData) else {
            return nil
        }

        let journalData = (try? Data(contentsOf: journalURL)) ?? Data()
        let points = JournalLineCodec.decodeLines(journalData)
        return PendingRecoverySession(metadata: metadata, points: points)
    }

    func clearJournal() {
        try? FileManager.default.removeItem(at: metadataURL)
        try? FileManager.default.removeItem(at: journalURL)
    }

    private func writeRecoveryMetadata(_ metadata: RecoveryMetadata) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL, options: .atomic)
    }
}
