import Foundation
import Observation
import UIKit

enum DiagnosticCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case lifecycle
    case auth
    case location
    case recording
    case recovery
    case backup
    case error

    var id: String { rawValue }

    var label: String {
        rawValue.uppercased()
    }
}

struct DiagnosticEntry: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let category: DiagnosticCategory
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: DiagnosticCategory,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.message = message
    }
}

@MainActor
@Observable
final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()

    private(set) var entries: [DiagnosticEntry] = []

    private let storageURL: URL
    private let maxEntries: Int

    init(storageURL: URL? = nil, maxEntries: Int = 2000) {
        self.maxEntries = max(1, maxEntries)
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.storageURL = appSupport
                .appendingPathComponent("Diagnostics", isDirectory: true)
                .appendingPathComponent("run_diagnostics.log")
        }
        loadPersistedEntries()
    }

    func log(_ category: DiagnosticCategory, _ message: String) {
        let entry = DiagnosticEntry(category: category, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        persistEntries()
    }

    func clear() {
        entries.removeAll()
        persistEntries()
    }

    func exportText(
        buildInfo: AppBuildInfo = .current(),
        locationSummary: String = "Passive check"
    ) -> String {
        let device = UIDevice.current
        var lines: [String] = [
            "=== RUN Diagnostics Export ===",
            "Generated: \(Date().ISO8601Format())",
            "App: \(buildInfo.appName) \(buildInfo.versionDisplay) [\(buildInfo.commitSHA)]",
            "Bundle ID: \(buildInfo.bundleIdentifier)",
            "Device: \(device.model) | \(device.systemName) \(device.systemVersion)",
            "Location Status: \(locationSummary)",
            "Entries: \(entries.count)",
            "------------------------------"
        ]

        for entry in entries {
            lines.append("[\(entry.timestamp.ISO8601Format())] [\(entry.category.label)] \(entry.message)")
        }
        return lines.joined(separator: "\n")
    }

    func exportFileURL(
        buildInfo: AppBuildInfo = .current(),
        locationSummary: String = "Passive check"
    ) -> URL? {
        let text = exportText(buildInfo: buildInfo, locationSummary: locationSummary)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RUN-Diagnostics.txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func loadPersistedEntries() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([DiagnosticEntry].self, from: data)
            if decoded.count > maxEntries {
                entries = Array(decoded.suffix(maxEntries))
            } else {
                entries = decoded
            }
        } catch {
            entries = []
        }
    }

    private func persistEntries() {
        do {
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Diagnostics persistence failure must never crash the app.
        }
    }
}
