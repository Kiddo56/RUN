import Foundation

public enum MovingTransition: Sendable, Equatable {
    case none
    case didAutoPause
    case didAutoResume
}

public struct MovingTimeEngine: Sendable {
    public var autoPauseEnabled: Bool
    public var autoPauseSpeedThresholdMPS: Double
    public var autoPauseDelaySeconds: TimeInterval
    public var resumeHysteresisFactor: Double

    public private(set) var elapsedTime: TimeInterval = 0
    public private(set) var movingTime: TimeInterval = 0
    public private(set) var isAutoPaused: Bool = false
    public private(set) var isManuallyPaused: Bool = false

    private var lastTimestamp: Date?
    private var lowSpeedSince: Date?

    public init(
        autoPauseEnabled: Bool = true,
        autoPauseSpeedThresholdMPS: Double = 0.8,
        autoPauseDelaySeconds: TimeInterval = 5.0,
        resumeHysteresisFactor: Double = 1.25
    ) {
        self.autoPauseEnabled = autoPauseEnabled
        self.autoPauseSpeedThresholdMPS = max(0.1, autoPauseSpeedThresholdMPS)
        self.autoPauseDelaySeconds = max(1.0, autoPauseDelaySeconds)
        self.resumeHysteresisFactor = max(1.0, resumeHysteresisFactor)
    }

    public mutating func start(at date: Date) {
        lastTimestamp = date
        lowSpeedSince = nil
        isAutoPaused = false
        isManuallyPaused = false
        elapsedTime = 0
        movingTime = 0
    }

    public mutating func pauseManually(at date: Date) {
        advanceElapsedOnly(to: date)
        isManuallyPaused = true
        lowSpeedSince = nil
    }

    public mutating func resumeManually(at date: Date) {
        advanceElapsedOnly(to: date)
        isManuallyPaused = false
        isAutoPaused = false
        lowSpeedSince = nil
    }

    @discardableResult
    public mutating func advance(to date: Date, speedMPS: Double?) -> MovingTransition {
        guard let prev = lastTimestamp else {
            lastTimestamp = date
            return .none
        }

        let dt = max(0, date.timeIntervalSince(prev))
        lastTimestamp = date
        elapsedTime += dt

        if isManuallyPaused {
            lowSpeedSince = nil
            return .none
        }

        if let speedMPS, speedMPS.isFinite {
            if !isAutoPaused {
                if speedMPS < autoPauseSpeedThresholdMPS {
                    if lowSpeedSince == nil {
                        lowSpeedSince = date
                    } else if autoPauseEnabled,
                              let lowStart = lowSpeedSince,
                              date.timeIntervalSince(lowStart) >= autoPauseDelaySeconds {
                        isAutoPaused = true
                        return .didAutoPause
                    }
                } else {
                    lowSpeedSince = nil
                }
            } else {
                let resumeThreshold = autoPauseSpeedThresholdMPS * resumeHysteresisFactor
                if speedMPS >= resumeThreshold {
                    isAutoPaused = false
                    lowSpeedSince = nil
                    movingTime += dt
                    return .didAutoResume
                }
            }
        } else if autoPauseEnabled, !isAutoPaused, let lowStart = lowSpeedSince,
                  date.timeIntervalSince(lowStart) >= autoPauseDelaySeconds {
            isAutoPaused = true
            return .didAutoPause
        }

        if !isAutoPaused {
            movingTime += dt
        }
        return .none
    }

    private mutating func advanceElapsedOnly(to date: Date) {
        guard let prev = lastTimestamp else {
            lastTimestamp = date
            return
        }
        let dt = max(0, date.timeIntervalSince(prev))
        lastTimestamp = date
        elapsedTime += dt
        if !isManuallyPaused && !isAutoPaused {
            movingTime += dt
        }
    }
}
