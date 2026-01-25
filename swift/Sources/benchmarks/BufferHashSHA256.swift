import Foundation
final class BufferHashSHA256: BufferHashBenchmark {
    struct SimpleSHA256 {
        static func digest(_ data: [UInt8]) -> [UInt8] {
            var result = [UInt8](repeating: 0, count: 32)
            // Используем 8 разных начальных хешей (как в SHA-256)
            var hashes: [UInt32] = [
                0x6a09e667,
                0xbb67ae85,
                0x3c6ef372,
                0xa54ff53a,
                0x510e527f,
                0x9b05688c,
                0x1f83d9ab,
                0x5be0cd19
            ]
            for (i, byte) in data.enumerated() {
                let hashIdx = i % 8
                var hash = hashes[hashIdx]
                // byte.toInt() and 0xFF как в Kotlin
                let byteUInt = UInt32(byte) & 0xFF
                hash = ((hash << 5) &+ hash) &+ byteUInt
                hash = (hash &+ (hash << 10)) ^ (hash >> 6)
                hashes[hashIdx] = hash
            }
            // Записываем все 8 хешей по 4 байта каждый (big-endian)
            for i in 0..<8 {
                let hash = hashes[i]
                result[i * 4] = UInt8((hash >> 24) & 0xFF)
                result[i * 4 + 1] = UInt8((hash >> 16) & 0xFF)
                result[i * 4 + 2] = UInt8((hash >> 8) & 0xFF)
                result[i * 4 + 3] = UInt8(hash & 0xFF)
            }
            return result
        }
    }
    override func test() -> UInt32 {
        // Доступ к data через self (которая наследуется)
        let bytes = SimpleSHA256.digest(self.data)
        // Little-endian чтение как в Kotlin
        return (UInt32(bytes[3]) << 24) |
               (UInt32(bytes[2]) << 16) |
               (UInt32(bytes[1]) << 8) |
               UInt32(bytes[0])
    }
}