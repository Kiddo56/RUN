import Foundation

public enum GPXReaderError: Error, Sendable, Equatable {
    case invalidXML
    case emptyTrack
}

public enum BasicGPXReader {
    public static func parseTrackPoints(from data: Data) throws -> [TrackPoint] {
        let delegate = GPXParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw GPXReaderError.invalidXML
        }
        return delegate.points
    }
}

private final class GPXParserDelegate: NSObject, XMLParserDelegate {
    var points: [TrackPoint] = []

    private var insideTrackPoint = false
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double = 0
    private var currentTime: Date?
    private var currentHR: Double?
    private var currentHAcc: Double = 5.0
    private var textBuffer = ""

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
        textBuffer = ""

        if localName == "trkpt" {
            insideTrackPoint = true
            currentLat = attributeDict["lat"].flatMap(Double.init)
            currentLon = attributeDict["lon"].flatMap(Double.init)
            currentEle = 0
            currentTime = nil
            currentHR = nil
            currentHAcc = 5.0
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideTrackPoint {
            textBuffer += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let localName = elementName.components(separatedBy: ":").last ?? elementName
        let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        guard insideTrackPoint else { return }

        switch localName {
        case "ele":
            if let val = Double(trimmed) {
                currentEle = val
            }
        case "time":
            currentTime = isoFractional.date(from: trimmed) ?? isoBasic.date(from: trimmed)
        case "hr":
            if let val = Double(trimmed) {
                currentHR = val
            }
        case "hAcc", "hdop":
            if let val = Double(trimmed) {
                currentHAcc = localName == "hdop" ? val * 4.0 : val
            }
        case "trkpt":
            if let lat = currentLat, let lon = currentLon {
                let ts = currentTime ?? Date(timeIntervalSince1970: Double(points.count))
                points.append(
                    TrackPoint(
                        timestamp: ts,
                        latitude: lat,
                        longitude: lon,
                        altitude: currentEle,
                        horizontalAccuracy: currentHAcc,
                        verticalAccuracy: 8.0,
                        speed: -1.0,
                        course: -1.0,
                        heartRate: currentHR,
                        isPaused: false
                    )
                )
            }
            insideTrackPoint = false
        default:
            break
        }
    }
}
