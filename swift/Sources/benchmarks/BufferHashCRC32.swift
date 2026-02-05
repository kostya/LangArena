import Foundation

final class BufferHashCRC32: BufferHashBenchmark {
    override init() {
        super.init()
    }

    override var name: String { return "BufferHashCRC32" }

    static let CRC_TABLE: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1
            }
            table[i] = crc
        }
        return table
    }()

    override func test() -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in self.data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ BufferHashCRC32.CRC_TABLE[index]
        }
        return crc ^ 0xFFFFFFFF
    }
}