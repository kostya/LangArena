import std/[random, algorithm]
import ../benchmark
import ../helper

type
  SortBenchmark* = ref object of Benchmark
    data*: seq[int32]
    sizeVal*: int64
    resultVal*: uint32

method prepare(self: SortBenchmark) =
  if self.sizeVal == 0:
    self.sizeVal = self.config_val("size")
    self.data = newSeq[int32](self.sizeVal)
    for i in 0..<self.sizeVal:
      self.data[i] = int32(nextInt(1_000_000))
    self.resultVal = 0

method test(self: SortBenchmark): seq[int32] {.base.} =
  raise newException(ValueError, "Not implemented")

method run(self: SortBenchmark, iteration_id: int) =
  self.resultVal += uint32(self.data[nextInt(self.sizeVal.int32)])
  let t = self.test()
  self.resultVal += uint32(t[nextInt(self.sizeVal.int32)])

method checksum(self: SortBenchmark): uint32 =
  self.resultVal
