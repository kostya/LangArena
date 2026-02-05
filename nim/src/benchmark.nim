import std/[json, times, math, tables, strutils, os]  
import config, helper

type
  Benchmark* = ref object of RootObj
    timeDelta*: float

method name*(self: Benchmark): string {.base.} =
  raise newException(ValueError, "Not implemented")

method run*(self: Benchmark, iteration_id: int) {.base.} =
  raise newException(ValueError, "Not implemented")

method checksum*(self: Benchmark): uint32 {.base.} =
  raise newException(ValueError, "Not implemented")

method prepare*(self: Benchmark) {.base.} =
  discard

method config_val*(self: Benchmark, field_name: string): int64 {.base.} =
  config_i64(self.name, field_name)

method iterations*(self: Benchmark): int64 {.base.} =
  self.config_val("iterations")

method expected_checksum*(self: Benchmark): int64 {.base.} =
  self.config_val("checksum")

method warmup_iterations*(self: Benchmark): int64 {.base.} =
  if CONFIG.hasKey(self.name) and CONFIG{self.name}.hasKey("warmup_iterations"):
    return CONFIG{self.name}{"warmup_iterations"}.getInt()
  else:
    let iters = self.iterations
    return max(int64(float(iters) * 0.2), 1'i64)

method warmup*(self: Benchmark) {.base.} =
  let prepare_iters = self.warmup_iterations
  for i in 0..<prepare_iters:
    self.run(i)

proc run_all*(self: Benchmark) =
  let iters = self.iterations
  for i in 0..<iters:
    self.run(i)

proc set_time_delta*(self: Benchmark, delta: float) =
  self.timeDelta = delta

proc customRound*(value: float, precision: int32): float =
  if classify(value) in {fcNan, fcInf, fcNegInf}:
    return value

  let factor = pow(10.0, float(precision))
  let scaled = value * factor

  let fraction = scaled - floor(scaled)

  if abs(fraction) < 0.5:
    result = floor(scaled) / factor
  elif abs(fraction) > 0.5:
    result = ceil(scaled) / factor
  else:
    result = (round(scaled / 2.0) * 2.0) / factor

proc toLower*(str: string): string =
  result = newString(str.len)
  for i, c in str:
    result[i] = toLowerAscii(c)

type
  BenchmarkFactory* = proc(): Benchmark

var registeredBenchmarks*: seq[tuple[name: string, factory: BenchmarkFactory]]

proc registerBenchmark*(name: string, factory: BenchmarkFactory) =
  registeredBenchmarks.add((name, factory))

proc all*(singleBench = "") =
  var results: Table[string, float]
  var summaryTime = 0.0
  var ok = 0
  var fails = 0

  for benchInfo in registeredBenchmarks:
    let name = benchInfo.name
    let createBenchmark = benchInfo.factory

    if singleBench.len > 0 and name.toLower.find(singleBench.toLower) == -1:
      continue

    stdout.write(name, ": ")
    stdout.flushFile()

    let bench = createBenchmark()
    reset()
    bench.prepare()

    bench.warmup
    reset()

    let start = epochTime()
    bench.run_all
    let duration = epochTime() - start

    bench.set_time_delta(duration)
    results[name] = duration

    if bench.checksum == bench.expected_checksum.uint32:
      stdout.write("OK ")
      inc ok
    else:
      stdout.write("ERR[actual=", $bench.checksum, ", expected=", $bench.expected_checksum, "] ")
      inc fails

    echo "in ", formatFloat(duration, ffDecimal, 3), "s"
    summaryTime += duration

    sleep(1)  

  let resultsFile = open("/tmp/results.js", fmWrite)
  resultsFile.write("{")
  var first = true
  for name, time in results.pairs:
    if not first:
      resultsFile.write(",")
    resultsFile.write("\"", name, "\":", formatFloat(time, ffDecimal))
    first = false
  resultsFile.write("}")
  resultsFile.close()

  if ok + fails > 0:
    echo "Summary: ", formatFloat(summaryTime, ffDecimal, 4), "s, ", ok+fails, ", ", ok, ", ", fails

  if fails > 0:
    quit(1)