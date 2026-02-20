import ../benchmark
import ../helper
import bufferhash_common

type
  BufferHashCRC32* = ref object of BufferHashBenchmark

proc newBufferHashCRC32(): Benchmark =
  BufferHashCRC32()

method name(self: BufferHashCRC32): string = "BufferHashCRC32"

proc crc32(data: seq[byte]): uint32 =
  var crc = 0xFFFFFFFF'u32

  for byteVal in data:
    crc = crc xor uint32(byteVal)
    for j in 0..<8:
      if (crc and 1) != 0:
        crc = (crc shr 1) xor 0xEDB88320'u32
      else:
        crc = crc shr 1

  crc xor 0xFFFFFFFF'u32

method test(self: BufferHashCRC32): uint32 =
  crc32(self.data)

registerBenchmark("BufferHashCRC32", newBufferHashCRC32)
