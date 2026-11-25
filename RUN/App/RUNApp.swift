import SwiftUI

enum AppTab: Hashable {
    case map
    case settings
}

@main
struct RUNApp: App {
    @State private var selectedTab: AppTab = .map
    @State private var settings = AppSettingsStore()
    @State private var diagnostics = DiagnosticsLogger.shared
    @State private var didLogLaunch = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                MapHomeView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }
                    .tag(AppTab.map)
                    .accessibilityIdentifier("tab.map")

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(AppTab.settings)
                    .accessibilityIdentifier("tab.settings")
            }
            .tint(RunTheme.electricTeal)
            .environment(settings)
            .environment(diagnostics)
            .task {
                guard !didLogLaunch else { return }
                didLogLaunch = true
                let info = AppBuildInfo.current()
                diagnostics.log(.lifecycle, "Launched \(info.appName) \(info.versionDisplay) [\(info.commitSHA)]")
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    diagnostics.log(.lifecycle, "Scene phase -> active")
                case .inactive:
                    diagnostics.log(.lifecycle, "Scene phase -> inactive")
                case .background:
                    diagnostics.log(.lifecycle, "Scene phase -> background")
                @unknown default:
                    diagnostics.log(.lifecycle, "Scene phase -> unknown")
                }
            }
        }
    }
}
