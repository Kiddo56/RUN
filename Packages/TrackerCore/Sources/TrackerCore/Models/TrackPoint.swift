import Foundation

public struct TrackPoint: Codable, Sendable, Equatable {
    public var timestamp: Date
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double
    public var horizontalAccuracy: Double
    public var verticalAccuracy: Double
    public var speed: Double
    public var course: Double
    public var heartRate: Double?
    public var isPaused: Bool

    public init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double = 0,
        horizontalAccuracy: Double = 5,
        verticalAccuracy: Double = 10,
        speed: Double = 0,
        course: Double = 0,
        heartRate: Double? = nil,
        isPaused: Bool = false
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.speed = speed
        self.course = course
        self.heartRate = heartRate
        self.isPaused = isPaused
    }
}
