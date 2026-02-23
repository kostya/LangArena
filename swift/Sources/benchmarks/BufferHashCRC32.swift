import Foundation

final class BufferHashCRC32: BufferHashBenchmark {
  override func test() -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF

    for byte in self.data {
      crc ^= UInt32(byte)

      for _ in 0..<8 {
        if crc & 1 != 0 {
          crc = (crc >> 1) ^ 0xEDB8_8320
        } else {
          crc >>= 1
        }
      }
    }

    return crc ^ 0xFFFF_FFFF
  }
  override func name() -> String {
    return "Hash::CRC32"
  }
}
