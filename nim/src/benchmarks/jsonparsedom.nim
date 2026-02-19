import std/[math, json]
import ../benchmark
import ../helper
import jsonbench_common

type
  JsonParseDom* = ref object of Benchmark
    text: string
    resultVal: uint32

proc newJsonParseDom(): Benchmark =
  JsonParseDom()

method name(self: JsonParseDom): string = "JsonParseDom"

method prepare(self: JsonParseDom) =
  let n = self.config_val("coords")
  self.text = getJsonText(n)
  self.resultVal = 0

method run(self: JsonParseDom, iteration_id: int) =
  let parsed = parseJson(self.text)

  var xSum, ySum, zSum: float
  var len = 0

  let coordinates = parsed["coordinates"]

  for coordNode in coordinates:
    xSum += coordNode["x"].getFloat()
    ySum += coordNode["y"].getFloat()
    zSum += coordNode["z"].getFloat()
    inc len

  if len > 0:
    let x = xSum / float(len)
    let y = ySum / float(len)
    let z = zSum / float(len)

    self.resultVal = self.resultVal + checksumF64(x) + checksumF64(y) +
        checksumF64(z)

method checksum(self: JsonParseDom): uint32 =
  self.resultVal

registerBenchmark("JsonParseDom", newJsonParseDom)
