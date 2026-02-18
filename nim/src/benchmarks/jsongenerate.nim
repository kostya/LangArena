import std/[strutils]
import jsony
import ../benchmark
import ../helper
import jsonbench_common

type
  JsonGenerate* = ref object of Benchmark
    n: int64
    data: JsonData
    resultJson: string
    resultVal: uint32

proc newJsonGenerate(): Benchmark =
  JsonGenerate()

method name(self: JsonGenerate): string = "JsonGenerate"

method prepare(self: JsonGenerate) =
  self.n = self.config_val("coords")
  self.resultVal = 0
  self.data = generateJsonData(self.n)

method run(self: JsonGenerate, iteration_id: int) =
  self.resultJson = self.data.toJson()
  if self.resultJson.startsWith("{\"coordinates\":"):
    self.resultVal = self.resultVal + 1

method checksum(self: JsonGenerate): uint32 =
  self.resultVal

proc getGeneratedJson*(self: JsonGenerate): string =
  self.resultJson

registerBenchmark("JsonGenerate", newJsonGenerate)