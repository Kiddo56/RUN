import SwiftUI
import UIKit

struct DiagnosticsView: View {
    @Environment(DiagnosticsLogger.self) private var diagnostics

    @State private var selectedCategory: DiagnosticCategory? = nil
    @State private var locationInspector = PassiveLocationInspector()
    @State private var exportURL: URL?

    private let buildInfo = AppBuildInfo.current()

    private var filteredEntries: [DiagnosticEntry] {
        let base: [DiagnosticEntry]
        if let selectedCategory {
            base = diagnostics.entries.filter { $0.category == selectedCategory }
        } else {
            base = diagnostics.entries
        }
        return base.reversed()
    }

    var body: some View {
        List {
            Section("Runtime Environment") {
                LabeledContent("Version", value: buildInfo.versionDisplay)
                LabeledContent("Commit SHA", value: buildInfo.commitSHA)
                LabeledContent("iOS Version", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                LabeledContent("Device", value: UIDevice.current.model)
                LabeledContent("Location Auth", value: locationInspector.summaryLine)
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterButton(title: "All", category: nil)
                        ForEach(DiagnosticCategory.allCases) { category in
                            filterButton(title: category.label, category: category)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button("Log Diagnostic Marker") {
                    diagnostics.log(.lifecycle, "Manual diagnostic marker added from Settings")
                }
                .accessibilityIdentifier("diagnostics.addEventButton")

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Export Diagnostics File", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("diagnostics.exportButton")
                } else {
                    ShareLink(item: diagnostics.exportText(buildInfo: buildInfo, locationSummary: locationInspector.summaryLine)) {
                        Label("Export Diagnostics Text", systemImage: "square.and.arrow.up")
                    }
                }

                Button("Clear Logs", role: .destructive) {
                    diagnostics.clear()
                    refreshExportFile()
                }
            } header: {
                Text("Controls")
            }

            Section("Event Log (\(filteredEntries.count))") {
                if filteredEntries.isEmpty {
                    Text("No diagnostic events recorded yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.category.label)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(color(for: entry.category).opacity(0.18))
                                    .foregroundStyle(color(for: entry.category))
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                                Spacer()

                                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            Text(entry.message)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshExportFile()
        }
        .onChange(of: diagnostics.entries.count) { _, _ in
            refreshExportFile()
        }
    }

    @ViewBuilder
    private func filterButton(title: String, category: DiagnosticCategory?) -> some View {
        let isSelected = selectedCategory == category
        Button(title) {
            selectedCategory = category
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? RunTheme.electricTeal : Color.secondary.opacity(0.15))
        .foregroundStyle(isSelected ? RunTheme.midnightSlate : Color.primary)
        .clipShape(Capsule())
        .buttonStyle(.plain)
    }

    private func color(for category: DiagnosticCategory) -> Color {
        switch category {
        case .lifecycle: return RunTheme.electricTeal
        case .auth: return RunTheme.violet
        case .location: return RunTheme.emerald
        case .recording: return RunTheme.emerald
        case .recovery: return RunTheme.amber
        case .backup: return RunTheme.electricTeal
        case .error: return RunTheme.coral
        }
    }

    private func refreshExportFile() {
        exportURL = diagnostics.exportFileURL(
            buildInfo: buildInfo,
            locationSummary: locationInspector.summaryLine
        )
    }
}
