import std/[algorithm, sequtils]
import ../benchmark

type
  Fannkuchredux* = ref object of Benchmark
    n: int64
    resultVal: uint32

proc newFannkuchredux(): Benchmark =
  Fannkuchredux()

method name(self: Fannkuchredux): string = "Fannkuchredux"

method prepare(self: Fannkuchredux) =
  self.n = self.config_val("n")
  self.resultVal = 0

proc fannkuchredux(n: int): (int, int) =
  var
    perm1: array[32, int]
    perm: array[32, int]
    count: array[32, int]

  for i in 0..<n:
    perm1[i] = i
  var maxFlipsCount = 0
  var permCount = 0
  var checksum = 0
  var r = n

  while true:
    while r > 1:
      count[r - 1] = r
      r.dec

    for i in 0..<n:
      perm[i] = perm1[i]

    var flipsCount = 0
    var k = perm[0]

    while k != 0:
      let k2 = (k + 1) div 2
      for i in 0..<k2:
        let j = k - i
        swap(perm[i], perm[j])
      flipsCount.inc
      k = perm[0]

    if flipsCount > maxFlipsCount:
      maxFlipsCount = flipsCount

    if permCount mod 2 == 0:
      checksum += flipsCount
    else:
      checksum -= flipsCount

    while true:
      if r == n:
        return (checksum, maxFlipsCount)

      let perm0 = perm1[0]
      for i in 0..<r:
        perm1[i] = perm1[i + 1]
      perm1[r] = perm0

      count[r].dec
      if count[r] > 0:
        break
      r.inc

    permCount.inc

method run(self: Fannkuchredux, iteration_id: int) =
  let (a, b) = fannkuchredux(self.n.int)
  self.resultVal = self.resultVal + (a * 100 + b).uint32

method checksum(self: Fannkuchredux): uint32 =
  self.resultVal

registerBenchmark("Fannkuchredux", newFannkuchredux)
