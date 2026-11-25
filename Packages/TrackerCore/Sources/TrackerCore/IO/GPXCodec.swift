import Foundation

public struct RouteWaypoint: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double?
    public var name: String?

    public init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        name: String? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.name = name
    }
}

public struct GPXDocument: Sendable, Equatable {
    public let name: String?
    public let activityType: ActivityType
    public let points: [TrackPoint]
    public let routeWaypoints: [RouteWaypoint]

    public init(
        name: String?,
        activityType: ActivityType,
        points: [TrackPoint],
        routeWaypoints: [RouteWaypoint]
    ) {
        self.name = name
        self.activityType = activityType
        self.points = points
        self.routeWaypoints = routeWaypoints
    }
}

public enum GPXCodecError: Error, Sendable, Equatable {
    case invalidXML
    case noCoordinatesFound
}

public enum GPXCodec {
    public static func exportActivity(
        title: String,
        activityType: ActivityType,
        startDate: Date,
        points: [TrackPoint]
    ) -> Data {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var lines: [String] = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<gpx version=\"1.1\" creator=\"RUN\" xmlns=\"http://www.topografix.com/GPX/1/1\">",
            "  <metadata>",
            "    <name>\(escapeXML(title))</name>",
            "    <time>\(iso.string(from: startDate))</time>",
            "  </metadata>",
            "  <trk>",
            "    <name>\(escapeXML(title))</name>",
            "    <type>\(escapeXML(activityType.rawValue))</type>"
        ]

        if !points.isEmpty {
            var segmentOpen = false
            for pt in points {
                if pt.isPaused {
                    if segmentOpen {
                        lines.append("    </trkseg>")
                        segmentOpen = false
                    }
                    continue
                }
                if !segmentOpen {
                    lines.append("    <trkseg>")
                    segmentOpen = true
                }
                lines.append(String(format: "      <trkpt lat=\"%.6f\" lon=\"%.6f\">", pt.latitude, pt.longitude))
                lines.append(String(format: "        <ele>%.2f</ele>", pt.altitude))
                lines.append("        <time>\(iso.string(from: pt.timestamp))</time>")
                if let hr = pt.heartRate, hr > 0 {
                    lines.append("        <extensions>")
                    lines.append("          <hr>\(Int(hr.rounded()))</hr>")
                    lines.append("        </extensions>")
                }
                lines.append("      </trkpt>")
            }
            if segmentOpen {
                lines.append("    </trkseg>")
            }
        }

        lines.append("  </trk>")
        lines.append("</gpx>")
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    public static func exportRoute(
        name: String,
        waypoints: [RouteWaypoint]
    ) -> Data {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var lines: [String] = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<gpx version=\"1.1\" creator=\"RUN\" xmlns=\"http://www.topografix.com/GPX/1/1\">",
            "  <metadata>",
            "    <name>\(escapeXML(name))</name>",
            "    <time>\(iso.string(from: Date()))</time>",
            "  </metadata>",
            "  <rte>",
            "    <name>\(escapeXML(name))</name>"
        ]

        for wp in waypoints {
            lines.append(String(format: "    <rtept lat=\"%.6f\" lon=\"%.6f\">", wp.latitude, wp.longitude))
            if let alt = wp.altitude {
                lines.append(String(format: "      <ele>%.2f</ele>", alt))
            }
            if let wpName = wp.name, !wpName.isEmpty {
                lines.append("      <name>\(escapeXML(wpName))</name>")
            }
            lines.append("    </rtept>")
        }

        lines.append("  </rte>")
        lines.append("</gpx>")
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    public static func parse(data: Data) throws -> GPXDocument {
        let delegate = FullGPXParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw GPXCodecError.invalidXML
        }

        let resolvedName = delegate.trackName ?? delegate.routeName ?? delegate.metadataName
        let resolvedType = parseActivityType(delegate.trackTypeRaw)
        let points = delegate.trackPoints

        var waypoints = delegate.routeWaypoints
        if waypoints.isEmpty && !points.isEmpty {
            waypoints = downsampleRouteWaypoints(from: points, maxCount: 250)
        }

        guard !points.isEmpty || !waypoints.isEmpty else {
            throw GPXCodecError.noCoordinatesFound
        }

        return GPXDocument(
            name: resolvedName,
            activityType: resolvedType,
            points: points,
            routeWaypoints: waypoints
        )
    }

    private static func downsampleRouteWaypoints(from points: [TrackPoint], maxCount: Int) -> [RouteWaypoint] {
        guard !points.isEmpty else { return [] }
        if points.count <= maxCount {
            return points.map { RouteWaypoint(latitude: $0.latitude, longitude: $0.longitude, altitude: $0.altitude) }
        }
        var out: [RouteWaypoint] = []
        out.reserveCapacity(maxCount)
        let step = Double(points.count - 1) / Double(maxCount - 1)
        for k in 0..<maxCount {
            let idx = min(points.count - 1, Int((Double(k) * step).rounded()))
            let pt = points[idx]
            out.append(RouteWaypoint(latitude: pt.latitude, longitude: pt.longitude, altitude: pt.altitude))
        }
        return out
    }

    private static func parseActivityType(_ raw: String?) -> ActivityType {
        guard let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !normalized.isEmpty else {
            return .run
        }
        if normalized.contains("ride") || normalized.contains("cycl") || normalized.contains("bike") {
            return .ride
        }
        if normalized.contains("walk") {
            return .walk
        }
        if normalized.contains("hike") {
            return .hike
        }
        if normalized.contains("run") {
            return .run
        }
        return .other
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private final class FullGPXParserDelegate: NSObject, XMLParserDelegate {
    var metadataName: String?
    var trackName: String?
    var trackTypeRaw: String?
    var routeName: String?
    var trackPoints: [TrackPoint] = []
    var routeWaypoints: [RouteWaypoint] = []

    private var elementStack: [String] = []
    private var textBuffer = ""

    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentTime: Date?
    private var currentHR: Double?
    private var currentHAcc: Double = 5.0
    private var currentPointName: String?
    private var inTrackPoint = false
    private var inRoutePoint = false

    private let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        elementStack.append(localName)
        textBuffer = ""

        if localName == "trkpt" {
            inTrackPoint = true
            resetPointFields(from: attributeDict)
        } else if localName == "rtept" {
            inRoutePoint = true
            resetPointFields(from: attributeDict)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = elementStack.count >= 2 ? elementStack[elementStack.count - 2] : ""

        if inTrackPoint || inRoutePoint {
            switch localName {
            case "ele":
                currentEle = Double(trimmed)
            case "time":
                currentTime = isoFractional.date(from: trimmed) ?? isoBasic.date(from: trimmed)
            case "hr":
                currentHR = Double(trimmed)
            case "hAcc", "hdop":
                if let v = Double(trimmed) {
                    currentHAcc = (localName == "hdop") ? (v * 4.0) : v
                }
            case "name":
                if !trimmed.isEmpty { currentPointName = trimmed }
            case "trkpt":
                if let lat = currentLat, let lon = currentLon {
                    let fallbackTime = Date(timeIntervalSince1970: Double(trackPoints.count))
                    trackPoints.append(
                        TrackPoint(
                            timestamp: currentTime ?? fallbackTime,
                            latitude: lat,
                            longitude: lon,
                            altitude: currentEle ?? 0.0,
                            horizontalAccuracy: currentHAcc,
                            verticalAccuracy: 8.0,
                            speed: -1.0,
                            course: -1.0,
                            heartRate: currentHR,
                            isPaused: false
                        )
                    )
                }
                inTrackPoint = false
            case "rtept":
                if let lat = currentLat, let lon = currentLon {
                    routeWaypoints.append(
                        RouteWaypoint(
                            latitude: lat,
                            longitude: lon,
                            altitude: currentEle,
                            name: currentPointName
                        )
                    )
                }
                inRoutePoint = false
            default:
                break
            }
        } else if localName == "name" && !trimmed.isEmpty {
            if parent == "metadata" { metadataName = trimmed }
            else if parent == "trk" { trackName = trimmed }
            else if parent == "rte" { routeName = trimmed }
        } else if localName == "type" && parent == "trk" && !trimmed.isEmpty {
            trackTypeRaw = trimmed
        }

        if !elementStack.isEmpty {
            elementStack.removeLast()
        }
    }

    private func resetPointFields(from attributes: [String: String]) {
        currentLat = attributes["lat"].flatMap(Double.init)
        currentLon = attributes["lon"].flatMap(Double.init)
        currentEle = nil
        currentTime = nil
        currentHR = nil
        currentHAcc = 5.0
        currentPointName = nil
    }
}
