import CoreLocation
import MapKit
import SwiftUI
import TrackerCore

enum MapStyleOption: String, CaseIterable, Identifiable {
    case standard
    case hybrid
    case satellite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "Standard"
        case .hybrid: return "Hybrid"
        case .satellite: return "Satellite"
        }
    }

    var symbolName: String {
        switch self {
        case .standard: return "map"
        case .hybrid: return "square.stack.3d.up"
        case .satellite: return "globe.americas.fill"
        }
    }

    var next: MapStyleOption {
        switch self {
        case .standard: return .hybrid
        case .hybrid: return .satellite
        case .satellite: return .standard
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .realistic)
        case .hybrid:
            return .hybrid(elevation: .realistic)
        case .satellite:
            return .imagery(elevation: .realistic)
        }
    }
}

enum MapFollowMode: String, CaseIterable, Identifiable {
    case off
    case follow
    case followWithHeading

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Free Pan"
        case .follow: return "Follow"
        case .followWithHeading: return "Heading"
        }
    }

    var symbolName: String {
        switch self {
        case .off: return "location"
        case .follow: return "location.fill"
        case .followWithHeading: return "location.north.line.fill"
        }
    }

    var next: MapFollowMode {
        switch self {
        case .off: return .follow
        case .follow: return .followWithHeading
        case .followWithHeading: return .off
        }
    }

    var cameraPosition: MapCameraPosition? {
        switch self {
        case .off:
            return nil
        case .follow:
            return .userLocation(followsHeading: false, fallback: .automatic)
        case .followWithHeading:
            return .userLocation(followsHeading: true, fallback: .automatic)
        }
    }
}

struct MapOverlayControlButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isActive ? RunTheme.midnightSlate : Color.primary)
                .frame(width: 44, height: 44)
                .background(isActive ? RunTheme.electricTeal : Color(.systemBackground).opacity(0.88))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

struct DistanceMilestonePill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RunTheme.midnightSlate.opacity(0.92))
            .overlay(
                Capsule()
                    .stroke(RunTheme.electricTeal, lineWidth: 1.2)
            )
            .clipShape(Capsule())
    }
}
