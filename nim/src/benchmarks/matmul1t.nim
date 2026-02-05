import std/[math, strutils]
import ../benchmark
import ../helper

type
  Matmul1T* = ref object of Benchmark
    n: int64
    resultVal: uint32

proc newMatmul1T(): Benchmark =
  Matmul1T()

method name(self: Matmul1T): string = "Matmul1T"

method prepare(self: Matmul1T) =
  self.n = self.config_val("n")
  self.resultVal = 0

proc matgen(n: int): seq[seq[float64]] {.inline.} =
  let tmp = 1.0 / float64(n * n)

  result = newSeq[seq[float64]](n)
  for i in 0..<n:
    result[i] = newSeq[float64](n)

  {.push checks: off.}
  for i in 0..<n:
    for j in 0..<n:
      result[i][j] = tmp * float64(i - j) * float64(i + j)
  {.pop.}

proc matmul_single_thread(a, b: seq[seq[float64]]): seq[seq[float64]] {.inline.} =
  let n = a.len

  var bT = newSeq[seq[float64]](n)
  for j in 0..<n:
    bT[j] = newSeq[float64](n)

  {.push checks: off.}
  for i in 0..<n:
    for j in 0..<n:
      bT[j][i] = b[i][j]
  {.pop.}

  result = newSeq[seq[float64]](n)
  for i in 0..<n:
    result[i] = newSeq[float64](n)

  {.push checks: off.}
  for i in 0..<n:
    let ai = a[i]
    for j in 0..<n:
      let bj = bT[j]
      var sum = 0.0

      for k in 0..<n:
        sum += ai[k] * bj[k]

      result[i][j] = sum
  {.pop.}

method run(self: Matmul1T, iteration_id: int) =
  let nInt = int(self.n)
  let a = matgen(nInt)
  let b = matgen(nInt)
  let c = matmul_single_thread(a, b)

  let centerIdx = nInt shr 1
  self.resultVal = self.resultVal + checksumF64(c[centerIdx][centerIdx])

method checksum(self: Matmul1T): uint32 =
  self.resultVal

registerBenchmark("Matmul1T", newMatmul1T)