import std/[json, times, math, tables, strutils]
import config, helper

type
  Benchmark* = ref object of RootObj

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

proc toLower*(str: string): string =
  result = newString(str.len)
  for i, c in str:
    result[i] = toLowerAscii(c)

type
  BenchmarkFactory* = proc(): Benchmark

var registeredBenchmarks*: Table[string, BenchmarkFactory]

proc registerBenchmark*(name: string, factory: BenchmarkFactory) =
  registeredBenchmarks[name] = factory

proc all*(singleBench = "") =
  var summaryTime = 0.0
  var ok = 0
  var fails = 0

  for name in ORDER:
    if singleBench.len > 0 and name.toLower.find(singleBench.toLower) == -1:
      continue

    let createBenchmark = registeredBenchmarks.getOrDefault(name)
    if createBenchmark == nil:
      echo "Warning: Benchmark '", name, "' defined in config but not found in code"
      continue

    stdout.write(name, ": ")
    stdout.flushFile()

    let bench = createBenchmark()
    reset()
    bench.prepare()

    bench.warmup
    GC_fullCollect()
    reset()

    let start = epochTime()
    bench.run_all
    let duration = epochTime() - start

    if bench.checksum == bench.expected_checksum.uint32:
      stdout.write("OK ")
      inc ok
    else:
      stdout.write("ERR[actual=", $bench.checksum, ", expected=",
          $bench.expected_checksum, "] ")
      inc fails

    echo "in ", formatFloat(duration, ffDecimal, 3), "s"
    summaryTime += duration

    GC_fullCollect()

  if ok + fails > 0:
    echo "Summary: ", formatFloat(summaryTime, ffDecimal, 4), "s, ", ok+fails,
        ", ", ok, ", ", fails

  if fails > 0:
    quit(1)
