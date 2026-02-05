import std/[algorithm]
import ../benchmark
import ../helper
import compression_common

type
  BWTHuffEncode* = ref object of Benchmark
    sizeVal*: int64
    testData*: seq[byte]
    resultVal*: uint32

proc newBWTHuffEncode(): Benchmark =
  BWTHuffEncode()

method name(self: BWTHuffEncode): string = "BWTHuffEncode"

method prepare(self: BWTHuffEncode) =
  self.sizeVal = self.config_val("size")
  self.testData = generateTestData(self.sizeVal)
  self.resultVal = 0

method run(self: BWTHuffEncode, iteration_id: int) =
  let compressed = compressData(self.testData)
  self.resultVal = self.resultVal + uint32(compressed.encodedBits.len)

method checksum(self: BWTHuffEncode): uint32 =
  self.resultVal

registerBenchmark("BWTHuffEncode", newBWTHuffEncode)