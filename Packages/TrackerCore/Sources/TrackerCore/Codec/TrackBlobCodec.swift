import Foundation

public enum TrackBlobError: Error, Sendable, Equatable {
    case invalidHeader
    case unsupportedVersion(UInt16)
    case corruptedPayload
}

/// Compact binary + zlib codec storing an entire `[TrackPoint]` array as one self-contained blob.
public enum TrackBlobCodec {
    private static let magic: [UInt8] = [0x52, 0x54, 0x52, 0x4B] // "RTRK"
    private static let version: UInt16 = 1
    private static let recordByteCount = 45 // 8+8+8 + 4+4+4+4+4+4 + 1

    public static func encode(_ points: [TrackPoint]) throws -> Data {
        var raw = Data(capacity: 10 + points.count * recordByteCount)
        raw.append(contentsOf: magic)
        appendLittleEndian(version, to: &raw)
        appendLittleEndian(UInt32(points.count), to: &raw)

        for pt in points {
            appendLittleEndian(pt.timestamp.timeIntervalSince1970.bitPattern, to: &raw)
            appendLittleEndian(pt.latitude.bitPattern, to: &raw)
            appendLittleEndian(pt.longitude.bitPattern, to: &raw)
            appendLittleEndian(Float(pt.altitude).bitPattern, to: &raw)
            appendLittleEndian(Float(pt.horizontalAccuracy).bitPattern, to: &raw)
            appendLittleEndian(Float(pt.verticalAccuracy).bitPattern, to: &raw)
            appendLittleEndian(Float(pt.speed).bitPattern, to: &raw)
            appendLittleEndian(Float(pt.course).bitPattern, to: &raw)
            let hrVal: Float = pt.heartRate.map { Float($0) } ?? -1.0
            appendLittleEndian(hrVal.bitPattern, to: &raw)
            let flags: UInt8 = pt.isPaused ? 1 : 0
            raw.append(flags)
        }

        let compressed = try (raw as NSData).compressed(using: .zlib)
        return compressed as Data
    }

    public static func decode(_ data: Data) throws -> [TrackPoint] {
        guard !data.isEmpty else { return [] }
        let raw = try (data as NSData).decompressed(using: .zlib) as Data
        guard raw.count >= 10 else {
            throw TrackBlobError.invalidHeader
        }
        guard Array(raw[0..<4]) == magic else {
            throw TrackBlobError.invalidHeader
        }

        let ver: UInt16 = readLittleEndian(from: raw, offset: 4)
        guard ver == version else {
            throw TrackBlobError.unsupportedVersion(ver)
        }

        let count: UInt32 = readLittleEndian(from: raw, offset: 6)
        let expectedSize = 10 + Int(count) * recordByteCount
        guard raw.count == expectedSize else {
            throw TrackBlobError.corruptedPayload
        }

        var points: [TrackPoint] = []
        points.reserveCapacity(Int(count))
        var offset = 10

        for _ in 0..<Int(count) {
            let tsBits: UInt64 = readLittleEndian(from: raw, offset: offset); offset += 8
            let latBits: UInt64 = readLittleEndian(from: raw, offset: offset); offset += 8
            let lonBits: UInt64 = readLittleEndian(from: raw, offset: offset); offset += 8
            let altBits: UInt32 = readLittleEndian(from: raw, offset: offset); offset += 4
            let hAccBits: UInt32 = readLittleEndian(from: raw, offset: offset); offset += 4
            let vAccBits: UInt32 = readLittleEndian(from: raw, offset: offset); offset += 4
            let speedBits: UInt32 = readLittleEndian(from: raw, offset: offset); offset += 4
            let courseBits: UInt32 = readLittleEndian(from: raw, offset: offset); offset += 4
            let hrBits: UInt32 = readLittleEndian(from: raw, offset: offset); offset += 4
            let flags = raw[offset]; offset += 1

            let hrFloat = Float(bitPattern: hrBits)
            let heartRate: Double? = hrFloat >= 0 ? Double(hrFloat) : nil

            points.append(
                TrackPoint(
                    timestamp: Date(timeIntervalSince1970: Double(bitPattern: tsBits)),
                    latitude: Double(bitPattern: latBits),
                    longitude: Double(bitPattern: lonBits),
                    altitude: Double(Float(bitPattern: altBits)),
                    horizontalAccuracy: Double(Float(bitPattern: hAccBits)),
                    verticalAccuracy: Double(Float(bitPattern: vAccBits)),
                    speed: Double(Float(bitPattern: speedBits)),
                    course: Double(Float(bitPattern: courseBits)),
                    heartRate: heartRate,
                    isPaused: (flags & 1) != 0
                )
            )
        }

        return points
    }

    private static func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func readLittleEndian<T: FixedWidthInteger>(from data: Data, offset: Int) -> T {
        var value: T = 0
        let size = MemoryLayout<T>.size
        _ = withUnsafeMutableBytes(of: &value) { dest in
            data.copyBytes(to: dest, from: offset..<(offset + size))
        }
        return T(littleEndian: value)
    }
}

/// Append-only newline-delimited JSON journal codec resilient to partial writes during force-quit.
public enum JournalLineCodec {
    public static func encodeBatch(_ points: [TrackPoint]) -> Data {
        guard !points.isEmpty else { return Data() }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var out = Data()
        for pt in points {
            if let line = try? encoder.encode(pt) {
                out.append(line)
                out.append(0x0A)
            }
        }
        return out
    }

    public static func decodeLines(_ data: Data) -> [TrackPoint] {
        guard !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var result: [TrackPoint] = []
        let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
        for slice in lines {
            if let point = try? decoder.decode(TrackPoint.self, from: Data(slice)) {
                result.append(point)
            }
        }
        return result
    }
}
