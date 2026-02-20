import std/[algorithm, options]
import ../benchmark
import ../helper
import compression_common
import bwthuffencode

type
  BWTHuffDecode* = ref object of BWTHuffEncode
    compressed: Option[CompressedData]
    decompressed: seq[byte]

proc newBWTHuffDecode(): Benchmark =
  BWTHuffDecode()

method name(self: BWTHuffDecode): string = "BWTHuffDecode"

method prepare(self: BWTHuffDecode) =
  self.sizeVal = self.config_val("size")
  self.testData = generateTestData(self.sizeVal)
  self.compressed = some(compressData(self.testData))
  self.resultVal = 0

method run(self: BWTHuffDecode, iteration_id: int) =
  self.decompressed = decompressData(self.compressed.get())

  self.resultVal = self.resultVal + uint32(self.decompressed.len)

method checksum(self: BWTHuffDecode): uint32 =
  var res = self.resultVal
  if self.testData == self.decompressed:
    res = res + 1_000_000'u32
  res

registerBenchmark("BWTHuffDecode", newBWTHuffDecode)
