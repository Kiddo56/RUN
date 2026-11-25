import Foundation

public struct PaceSmoother: Sendable {
    public struct Sample: Sendable {
        public let timestamp: Date
        public let cumulativeDistanceMeters: Double
    }

    public let windowSeconds: TimeInterval
    public let minDistanceMeters: Double
    private var samples: [Sample] = []

    public init(windowSeconds: TimeInterval = 10.0, minDistanceMeters: Double = 5.0) {
        self.windowSeconds = max(2.0, windowSeconds)
        self.minDistanceMeters = max(1.0, minDistanceMeters)
    }

    public mutating func reset() {
        samples.removeAll()
    }

    public mutating func append(timestamp: Date, cumulativeDistanceMeters: Double) {
        if let last = samples.last, timestamp <= last.timestamp {
            return
        }
        samples.append(Sample(timestamp: timestamp, cumulativeDistanceMeters: cumulativeDistanceMeters))

        let cutoff = timestamp.addingTimeInterval(-windowSeconds)
        while samples.count > 2, samples[1].timestamp <= cutoff {
            samples.removeFirst()
        }
    }

    public var smoothedSpeedMPS: Double {
        guard let first = samples.first, let last = samples.last else {
            return 0
        }
        let dt = last.timestamp.timeIntervalSince(first.timestamp)
        let dist = max(0, last.cumulativeDistanceMeters - first.cumulativeDistanceMeters)
        guard dt >= 1.5, dist >= minDistanceMeters else {
            return 0
        }
        return dist / dt
    }

    public var smoothedPaceSecondsPerMeter: Double {
        let speed = smoothedSpeedMPS
        guard speed > 0.1 else { return 0 }
        return 1.0 / speed
    }
}
