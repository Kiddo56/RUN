import SwiftData
import SwiftUI
import TrackerCore

enum AppTab: Hashable {
    case record
    case history
    case insights
    case settings
}

@main
struct RUNApp: App {
    @State private var selectedTab: AppTab = .record
    @State private var settings = AppSettingsStore()
    @State private var diagnostics = DiagnosticsLogger.shared
    @State private var recorder = LocationRecordingService()
    @State private var didPerformStartupCheck = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                RecordView()
                    .tabItem {
                        Label("Record", systemImage: "figure.run")
                    }
                    .tag(AppTab.record)

                HistoryListView()
                    .tabItem {
                        Label("History", systemImage: "list.bullet.rectangle")
                    }
                    .tag(AppTab.history)

                InsightsDashboardView()
                    .tabItem {
                        Label("Insights", systemImage: "chart.bar.xaxis")
                    }
                    .tag(AppTab.insights)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(AppTab.settings)
            }
            .tint(RunTheme.electricTeal)
            .environment(settings)
            .environment(diagnostics)
            .environment(recorder)
            .task {
                guard !didPerformStartupCheck else { return }
                didPerformStartupCheck = true
                let info = AppBuildInfo.current()
                diagnostics.log(.lifecycle, "Launched \(info.appName) \(info.versionDisplay) [\(info.commitSHA)]")
                recorder.checkForPendingRecovery()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    diagnostics.log(.lifecycle, "Scene phase -> active")
                case .inactive:
                    diagnostics.log(.lifecycle, "Scene phase -> inactive")
                    recorder.flushForBackgroundTransition()
                case .background:
                    diagnostics.log(.lifecycle, "Scene phase -> background")
                    recorder.flushForBackgroundTransition()
                @unknown default:
                    diagnostics.log(.lifecycle, "Scene phase -> unknown")
                }
            }
        }
        .modelContainer(for: [
            SDActivity.self,
            SDGear.self,
            SDGoal.self,
            SDSavedRoute.self,
            SDSection.self
        ])
    }
}
