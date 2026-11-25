import SwiftData
import SwiftUI
import TrackerCore

enum AppTab: Hashable {
    case record
    case history
    case routes
    case insights
    case settings
}

@main
struct RUNApp: App {
    @State private var selectedTab: AppTab = .record
    @State private var settings = AppSettingsStore()
    @State private var diagnostics = DiagnosticsLogger.shared
    @State private var recorder = LocationRecordingService()
    @State private var heartRateMonitor = HeartRateMonitorService()
    @State private var barometer = BarometerService()
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

                RoutesListView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Routes", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                    .tag(AppTab.routes)

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
            .environment(heartRateMonitor)
            .environment(barometer)
            .task {
                guard !didPerformStartupCheck else { return }
                didPerformStartupCheck = true
                let info = AppBuildInfo.current()
                diagnostics.log(.lifecycle, "Launched \(info.appName) \(info.versionDisplay) [\(info.commitSHA)]")
                configureRecorderSensorHooks()
                recorder.checkForPendingRecovery()
            }
            .onChange(of: settings.featureFlags.bleHeartRate) { _, enabled in
                if !enabled {
                    heartRateMonitor.disconnectAndStop()
                }
            }
            .onChange(of: settings.featureFlags.barometricAltimeter) { _, enabled in
                if !enabled {
                    barometer.stopSession()
                } else if recorder.state.isActiveSession {
                    barometer.startSession()
                }
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

    private func configureRecorderSensorHooks() {
        recorder.currentHeartRateProvider = { [settings, heartRateMonitor] in
            settings.featureFlags.bleHeartRate ? heartRateMonitor.currentBPM : nil
        }
        recorder.currentBarometricAltitudeProvider = { [settings, barometer] in
            settings.featureFlags.barometricAltimeter ? barometer.fusedAltitudeMeters : nil
        }
        recorder.onSessionStarted = { [settings, barometer] in
            if settings.featureFlags.barometricAltimeter {
                barometer.startSession()
            }
        }
        recorder.onSessionEnded = { [barometer] in
            barometer.stopSession()
        }
        recorder.onGPSAltitudeAvailable = { [settings, barometer] altitude, verticalAccuracy in
            if settings.featureFlags.barometricAltimeter {
                barometer.seedBaselineIfNeeded(gpsAltitude: altitude, verticalAccuracy: verticalAccuracy)
            }
        }
    }
}
