import std/[math]
import jsony
import ../benchmark
import ../helper
import jsonbench_common

type
  JsonParseMapping* = ref object of Benchmark
    text: string
    resultVal: uint32

proc newJsonParseMapping(): Benchmark =
  JsonParseMapping()

method name(self: JsonParseMapping): string = "JsonParseMapping"

method prepare(self: JsonParseMapping) =
  let n = self.config_val("coords")
  self.text = getJsonText(n)
  self.resultVal = 0

method run(self: JsonParseMapping, iteration_id: int) =
  let data = self.text.fromJson(JsonData)

  var xSum, ySum, zSum: float
  var len = 0

  for coord in data.coordinates:
    xSum += coord.x
    ySum += coord.y
    zSum += coord.z
    inc len

  if len > 0:
    let x = xSum / float(len)
    let y = ySum / float(len)
    let z = zSum / float(len)

    self.resultVal = self.resultVal + checksumF64(x) + checksumF64(y) +
        checksumF64(z)

method checksum(self: JsonParseMapping): uint32 =
  self.resultVal

registerBenchmark("JsonParseMapping", newJsonParseMapping)
