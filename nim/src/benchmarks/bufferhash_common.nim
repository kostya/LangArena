import std/[random]
import ../benchmark
import ../helper

type
  BufferHashBenchmark* = ref object of Benchmark
    data*: seq[byte]
    sizeVal*: int64
    resultVal*: uint32

method prepare(self: BufferHashBenchmark) =
  if self.sizeVal == 0:
    self.sizeVal = self.config_val("size")
    self.data = newSeq[byte](self.sizeVal)
    for i in 0..<self.sizeVal:
      self.data[i] = byte(nextInt(256))
    self.resultVal = 0

method test*(self: BufferHashBenchmark): uint32 {.base.} =
  raise newException(ValueError, "Not implemented")

method run(self: BufferHashBenchmark, iteration_id: int) =
  self.resultVal = self.resultVal + self.test()

method checksum(self: BufferHashBenchmark): uint32 =
  self.resultVal