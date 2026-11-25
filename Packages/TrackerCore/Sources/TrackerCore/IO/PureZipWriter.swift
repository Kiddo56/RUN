import Foundation

public struct ZipEntry: Sendable, Equatable {
    public let fileName: String
    public let data: Data

    public init(fileName: String, data: Data) {
        self.fileName = fileName
        self.data = data
    }
}

/// Pure-Swift PKZIP STORE (method 0) archive generator requiring zero third-party dependencies.
public enum PureZipWriter {
    public static func createArchive(entries: [ZipEntry]) -> Data {
        var archive = Data()
        var centralDirectory = Data()

        for entry in entries {
            let nameData = Data(entry.fileName.utf8)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)
            let localOffset = UInt32(archive.count)

            // Local file header
            appendUInt32(0x0403_4B50, to: &archive)
            appendUInt16(20, to: &archive)           // version needed
            appendUInt16(0x0800, to: &archive)       // UTF-8 filename flag
            appendUInt16(0, to: &archive)            // compression method: STORE
            appendUInt16(0, to: &archive)            // mod time
            appendUInt16(0x5421, to: &archive)       // mod date
            appendUInt32(crc, to: &archive)
            appendUInt32(size, to: &archive)         // compressed size
            appendUInt32(size, to: &archive)         // uncompressed size
            appendUInt16(UInt16(nameData.count), to: &archive)
            appendUInt16(0, to: &archive)            // extra length
            archive.append(nameData)
            archive.append(entry.data)

            // Central directory file header
            appendUInt32(0x0201_4B50, to: &centralDirectory)
            appendUInt16(20, to: &centralDirectory)  // version made by
            appendUInt16(20, to: &centralDirectory)  // version needed
            appendUInt16(0x0800, to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)   // STORE
            appendUInt16(0, to: &centralDirectory)
            appendUInt16(0x5421, to: &centralDirectory)
            appendUInt32(crc, to: &centralDirectory)
            appendUInt32(size, to: &centralDirectory)
            appendUInt32(size, to: &centralDirectory)
            appendUInt16(UInt16(nameData.count), to: &centralDirectory)
            appendUInt16(0, to: &centralDirectory)   // extra length
            appendUInt16(0, to: &centralDirectory)   // comment length
            appendUInt16(0, to: &centralDirectory)   // disk number
            appendUInt16(0, to: &centralDirectory)   // internal attrs
            appendUInt32(0, to: &centralDirectory)   // external attrs
            appendUInt32(localOffset, to: &centralDirectory)
            centralDirectory.append(nameData)
        }

        let cdOffset = UInt32(archive.count)
        let cdSize = UInt32(centralDirectory.count)
        archive.append(centralDirectory)

        // End of central directory record
        appendUInt32(0x0605_4B50, to: &archive)
        appendUInt16(0, to: &archive)
        appendUInt16(0, to: &archive)
        appendUInt16(UInt16(entries.count), to: &archive)
        appendUInt16(UInt16(entries.count), to: &archive)
        appendUInt32(cdSize, to: &archive)
        appendUInt32(cdOffset, to: &archive)
        appendUInt16(0, to: &archive)

        return archive
    }

    public static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = UInt32(bitPattern: -Int32(crc & 1))
                crc = (crc >> 1) ^ (0xEDB8_8320 & mask)
            }
        }
        return ~crc
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }
}
