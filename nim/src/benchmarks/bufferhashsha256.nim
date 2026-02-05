import ../benchmark
import ../helper
import bufferhash_common

type
  BufferHashSHA256* = ref object of BufferHashBenchmark

proc newBufferHashSHA256(): Benchmark =
  BufferHashSHA256()

method name(self: BufferHashSHA256): string = "BufferHashSHA256"

proc simpleSHA256(data: seq[byte]): uint32 =
  var hashes: array[8, uint32] = [
    0x6a09e667'u32, 0xbb67ae85'u32, 0x3c6ef372'u32, 0xa54ff53a'u32,
    0x510e527f'u32, 0x9b05688c'u32, 0x1f83d9ab'u32, 0x5be0cd19'u32
  ]

  for i, byteVal in data:
    let hashIdx = i mod 8
    var hash = hashes[hashIdx]
    hash = ((hash shl 5) + hash) + uint32(byteVal)
    hash = (hash + (hash shl 10)) xor (hash shr 6)
    hashes[hashIdx] = hash

  result = (hashes[0] shr 24) or
           ((hashes[0] shr 16) and 0xFF) shl 8 or
           ((hashes[0] shr 8) and 0xFF) shl 16 or
           (hashes[0] and 0xFF) shl 24

method test(self: BufferHashSHA256): uint32 =
  simpleSHA256(self.data)

registerBenchmark("BufferHashSHA256", newBufferHashSHA256)