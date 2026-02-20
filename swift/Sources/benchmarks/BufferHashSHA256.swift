import Foundation

final class BufferHashSHA256: BufferHashBenchmark {
  override init() {
    super.init()
  }

  override var name: String { return "BufferHashSHA256" }

  struct SimpleSHA256 {
    static func digest(_ data: [UInt8]) -> [UInt8] {
      var result = [UInt8](repeating: 0, count: 32)
      var hashes: [UInt32] = [
        0x6a09_e667,
        0xbb67_ae85,
        0x3c6e_f372,
        0xa54f_f53a,
        0x510e_527f,
        0x9b05_688c,
        0x1f83_d9ab,
        0x5be0_cd19,
      ]

      for (i, byte) in data.enumerated() {
        let hashIdx = i % 8
        var hash = hashes[hashIdx]
        let byteUInt = UInt32(byte) & 0xFF
        hash = ((hash << 5) &+ hash) &+ byteUInt
        hash = (hash &+ (hash << 10)) ^ (hash >> 6)
        hashes[hashIdx] = hash
      }

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
    let bytes = SimpleSHA256.digest(self.data)
    return (UInt32(bytes[3]) << 24) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[1]) << 8)
      | UInt32(bytes[0])
  }
}
