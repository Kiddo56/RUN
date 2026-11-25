import Foundation

public enum BLEHeartRateParser {
    /// Parses a Bluetooth SIG Heart Rate Measurement characteristic payload (`0x2A37`).
    /// Bit 0 of the flags byte specifies 8-bit (`0`) vs little-endian 16-bit (`1`) BPM.
    public static func parseBPM(from data: Data) -> Double? {
        guard data.count >= 2 else { return nil }
        let start = data.startIndex
        let flags = data[start]
        let is16Bit = (flags & 0x01) != 0

        if !is16Bit {
            let bpm = Int(data[start + 1])
            guard bpm > 0 else { return nil }
            return Double(bpm)
        } else {
            guard data.count >= 3 else { return nil }
            let lo = UInt16(data[start + 1])
            let hi = UInt16(data[start + 2])
            let bpm = Int(lo | (hi << 8))
            guard bpm > 0 else { return nil }
            return Double(bpm)
        }
    }
}
