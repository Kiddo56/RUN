import SwiftData
import SwiftUI
import TrackerCore
import UniformTypeIdentifiers

struct DataAndBackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettingsStore.self) private var settings

    @Query(sort: \SDActivity.startDate, order: .reverse) private var activities: [SDActivity]
    @Query private var gearList: [SDGear]

    @State private var replaceExistingOnRestore = false
    @State private var showingBackupImporter = false
    @State private var showingGPXImporter = false

    @State private var preparedBackupURL: URL?
    @State private var preparedBulkZipURL: URL?
    @State private var preparedCSVURL: URL?

    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false

    private let buildInfo = AppBuildInfo.current()

    var body: some View {
        Form {
            Section {
                LabeledContent("Last Backup", value: lastBackupDescription)
                LabeledContent("Saved Activities", value: "\(activities.count)")
            } header: {
                Text("Backup Status")
            } footer: {
                Text("Free Apple ID signing expires every 7 days. Export a full backup regularly to Files or iCloud Drive before re-signing or reinstalling.")
            }

            Section("Full-Fidelity Backup & Restore") {
                Button {
                    generateBackup()
                } label: {
                    Label("Create Full Backup (.json)", systemImage: "externaldrive.badge.plus")
                }

                if let preparedBackupURL {
                    ShareLink(item: preparedBackupURL) {
                        Label("Save / Share Backup File", systemImage: "square.and.arrow.up")
                            .foregroundStyle(RunTheme.electricTeal)
                    }
                }

                Toggle("Replace All Existing Data on Restore", isOn: $replaceExistingOnRestore)

                Button {
                    showingBackupImporter = true
                } label: {
                    Label("Restore From Backup File…", systemImage: "arrow.counterclockwise.circle")
                }
            }

            Section("GPX & CSV Export") {
                Button {
                    generateBulkZip()
                } label: {
                    Label("Prepare Bulk GPX Archive (.zip)", systemImage: "doc.zipper")
                }
                .disabled(activities.isEmpty)

                if let preparedBulkZipURL {
                    ShareLink(item: preparedBulkZipURL) {
                        Label("Share Bulk GPX (.zip)", systemImage: "square.and.arrow.up")
                            .foregroundStyle(RunTheme.electricTeal)
                    }
                }

                Button {
                    generateCSV()
                } label: {
                    Label("Prepare CSV Summary (.csv)", systemImage: "tablecells")
                }
                .disabled(activities.isEmpty)

                if let preparedCSVURL {
                    ShareLink(item: preparedCSVURL) {
                        Label("Share CSV Summary (.csv)", systemImage: "square.and.arrow.up")
                            .foregroundStyle(RunTheme.electricTeal)
                    }
                }
            }

            Section("Import") {
                Button {
                    showingGPXImporter = true
                } label: {
                    Label("Import GPX Activity…", systemImage: "square.and.arrow.down")
                }
            }
        }
        .navigationTitle("Backup & Export")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [.json]
        ) { result in
            handleBackupRestore(result)
        }
        .fileImporter(
            isPresented: $showingGPXImporter,
            allowedContentTypes: DataTransferService.gpxContentTypes
        ) { result in
            handleGPXImport(result)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var lastBackupDescription: String {
        guard let date = settings.lastBackupDate else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func generateBackup() {
        do {
            preparedBackupURL = try DataTransferService.exportFullBackup(
                modelContext: modelContext,
                settings: settings,
                appVersion: buildInfo.versionDisplay
            )
        } catch {
            presentAlert(title: "Backup Failed", message: error.localizedDescription)
        }
    }

    private func generateBulkZip() {
        do {
            preparedBulkZipURL = try DataTransferService.exportBulkGPXZip(activities: activities)
        } catch {
            presentAlert(title: "GPX Export Failed", message: error.localizedDescription)
        }
    }

    private func generateCSV() {
        do {
            preparedCSVURL = try DataTransferService.exportCSVSummary(
                activities: activities,
                gearList: gearList,
                unitSystem: settings.unitSystem
            )
        } catch {
            presentAlert(title: "CSV Export Failed", message: error.localizedDescription)
        }
    }

    private func handleBackupRestore(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let summary = try DataTransferService.restoreFullBackup(
                    from: url,
                    modelContext: modelContext,
                    settings: settings,
                    replaceExisting: replaceExistingOnRestore
                )
                presentAlert(
                    title: "Restore Complete",
                    message: "Restored \(summary.activitiesRestored) activities, \(summary.gearRestored) gear, \(summary.goalsRestored) goals, and \(summary.routesRestored) routes."
                )
            } catch {
                presentAlert(title: "Restore Failed", message: error.localizedDescription)
            }
        case .failure(let error):
            presentAlert(title: "Import Cancelled", message: error.localizedDescription)
        }
    }

    private func handleGPXImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let imported = try DataTransferService.importGPXAsActivity(
                    from: url,
                    modelContext: modelContext,
                    settings: settings
                )
                presentAlert(
                    title: "Activity Imported",
                    message: "Imported '\(imported.title)' (\(RunFormatter.distance(meters: imported.distanceMeters, unit: settings.unitSystem)))."
                )
            } catch {
                presentAlert(title: "GPX Import Failed", message: error.localizedDescription)
            }
        case .failure(let error):
            presentAlert(title: "Import Cancelled", message: error.localizedDescription)
        }
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}
