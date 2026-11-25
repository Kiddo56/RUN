import CoreLocation
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

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        let acc = manager.accuracyAuthorization
        Task { @MainActor in
            self.authorizationStatus = auth
            self.accuracyAuthorization = acc
        }
    }
}
