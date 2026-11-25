import CoreLocation
import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class PassiveLocationInspector: NSObject, CLLocationManagerDelegate {
    private let manager: CLLocationManager

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var accuracyAuthorization: CLAccuracyAuthorization

    override init() {
        let mgr = CLLocationManager()
        self.manager = mgr
        self.authorizationStatus = mgr.authorizationStatus
        self.accuracyAuthorization = mgr.accuracyAuthorization
        super.init()
        mgr.delegate = self
    }

    var statusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Not Requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When In Use"
        @unknown default:
            return "Unknown"
        }
    }

    var accuracyDescription: String {
        switch accuracyAuthorization {
        case .fullAccuracy:
            return "Full Accuracy"
        case .reducedAccuracy:
            return "Reduced Accuracy"
        @unknown default:
            return "Unknown"
        }
    }

    var summaryLine: String {
        "\(statusDescription) · \(accuracyDescription)"
    }

    var badgeColor: Color {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return accuracyAuthorization == .fullAccuracy ? RunTheme.emerald : RunTheme.amber
        case .denied, .restricted:
            return RunTheme.coral
        case .notDetermined:
            return RunTheme.electricTeal
        @unknown default:
            return RunTheme.amber
        }
    }

    func requestPermissionIfNeeded() {
        if authorizationStatus == .notDetermined {
            DiagnosticsLogger.shared.log(.auth, "User requested When-In-Use location permission")
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        let acc = manager.accuracyAuthorization
        Task { @MainActor in
            self.authorizationStatus = auth
            self.accuracyAuthorization = acc
            DiagnosticsLogger.shared.log(.auth, "Location authorization changed: \(self.summaryLine)")
        }
    }
}

struct MapHomeView: View {
    @Binding var selectedTab: AppTab
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var locationInspector = PassiveLocationInspector()

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .accessibilityIdentifier("map.canvas")

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RUN")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("GPS: \(locationInspector.statusDescription)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(locationInspector.badgeColor)
                    }

                    Spacer()

                    if locationInspector.authorizationStatus == .notDetermined {
                        Button("Enable GPS") {
                            locationInspector.requestPermissionIfNeeded()
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RunTheme.electricTeal)
                        .foregroundStyle(RunTheme.midnightSlate)
                        .clipShape(Capsule())
                        .accessibilityLabel("Enable location permission")
                    }

                    Button {
                        selectedTab = .settings
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RunTheme.electricTeal)
                            .padding(8)
                            .background(RunTheme.hudBorder.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Open Settings")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RunTheme.hudSurface.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RunTheme.hudBorder.opacity(0.8), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
}
