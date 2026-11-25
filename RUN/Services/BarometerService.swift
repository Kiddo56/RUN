import CoreMotion
import Foundation
import Observation

@MainActor
@Observable
final class BarometerService {
    private(set) var isRunning = false
    private(set) var isReceivingUpdates = false
    private(set) var fusedAltitudeMeters: Double?
    private(set) var latestRelativeAltitudeMeters: Double?

    var isHardwareAvailable: Bool {
        CMAltimeter.isRelativeAltitudeAvailable()
    }

    private var altimeter: CMAltimeter?
    private var baselineGPSAltitude: Double?
    private var baselineRelativeOffset: Double?

    func startSession() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            DiagnosticsLogger.shared.log(.location, "Barometric altimeter unavailable on this device")
            return
        }

        altimeter?.stopRelativeAltitudeUpdates()
        baselineGPSAltitude = nil
        baselineRelativeOffset = nil
        fusedAltitudeMeters = nil
        latestRelativeAltitudeMeters = nil
        isReceivingUpdates = false

        let instance = CMAltimeter()
        altimeter = instance
        isRunning = true

        instance.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            let relAlt = data?.relativeAltitude.doubleValue
            let errText = error?.localizedDescription
            Task { @MainActor [weak self] in
                self?.handleUpdate(relativeAltitude: relAlt, errorDescription: errText)
            }
        }
        DiagnosticsLogger.shared.log(.recording, "Started barometric altimeter session")
    }

    func seedBaselineIfNeeded(gpsAltitude: Double, verticalAccuracy: Double) {
        guard isRunning,
              baselineGPSAltitude == nil,
              gpsAltitude.isFinite,
              verticalAccuracy >= 0,
              verticalAccuracy <= 30.0 else {
            return
        }

        baselineGPSAltitude = gpsAltitude
        if let rel = latestRelativeAltitudeMeters {
            baselineRelativeOffset = rel
            fusedAltitudeMeters = gpsAltitude
        }
    }

    func stopSession() {
        if isRunning {
            DiagnosticsLogger.shared.log(.recording, "Stopped barometric altimeter session")
        }
        altimeter?.stopRelativeAltitudeUpdates()
        altimeter = nil
        isRunning = false
        isReceivingUpdates = false
        baselineGPSAltitude = nil
        baselineRelativeOffset = nil
        latestRelativeAltitudeMeters = nil
        fusedAltitudeMeters = nil
    }

    private func handleUpdate(relativeAltitude: Double?, errorDescription: String?) {
        if let errorDescription {
            DiagnosticsLogger.shared.log(.error, "Barometric altimeter error: \(errorDescription)")
            return
        }
        guard isRunning, let rel = relativeAltitude, rel.isFinite else { return }

        isReceivingUpdates = true
        latestRelativeAltitudeMeters = rel

        if let baseGPS = baselineGPSAltitude {
            if baselineRelativeOffset == nil {
                baselineRelativeOffset = rel
            }
            let baseRel = baselineRelativeOffset ?? rel
            fusedAltitudeMeters = baseGPS + (rel - baseRel)
        }
    }
}
