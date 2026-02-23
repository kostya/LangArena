import std/[math, strutils, os, cpuinfo]
import ../benchmark
import ../helper

type
  MatmulBase* = ref object of Benchmark
    n: int64
    resultVal: uint32

  Matmul4T* = ref object of MatmulBase
  Matmul8T* = ref object of MatmulBase
  Matmul16T* = ref object of MatmulBase

proc matgen(n: int): seq[seq[float64]] =
  let tmp = 1.0 / float64(n * n)
  result = newSeq[seq[float64]](n)
  for i in 0..<n:
    var row = newSeq[float64](n)
    for j in 0..<n:
      row[j] = tmp * float64(i - j) * float64(i + j)
    result[i] = row

proc transpose(b: seq[seq[float64]]): seq[seq[float64]] =
  let size = b.len
  result = newSeq[seq[float64]](size)
  for i in 0..<size:
    result[i] = newSeq[float64](size)
  for i in 0..<size:
    for j in 0..<size:
      result[j][i] = b[i][j]

type
  ThreadData = object
    a: ptr seq[seq[float64]]
    bT: ptr seq[seq[float64]]
    c: ptr seq[seq[float64]]
    threadId: int
    numThreads: int
    n: int

proc worker(data: ThreadData) {.thread.} =

  var i = data.threadId
  while i < data.n:

    let ai = data.a[][i]
    for j in 0..<data.n:
      var sum = 0.0
      for k in 0..<data.n:
        sum += ai[k] * data.bT[][j][k]
      data.c[][i][j] = sum
    i += data.numThreads

method numThreads(self: MatmulBase): int {.base.} = 1
method name(self: MatmulBase): string = "MatmulBase"

method prepare(self: MatmulBase) =
  self.n = self.config_val("n")
  self.resultVal = 0

proc matmul_parallel(self: MatmulBase, a, b: seq[seq[float64]]): seq[seq[float64]] =
  let n = int(self.n)

  let bT = transpose(b)

  result = newSeq[seq[float64]](n)
  for i in 0..<n:
    result[i] = newSeq[float64](n)

  var aPtr = unsafeAddr a
  var bTPtr = unsafeAddr bT
  var cPtr = unsafeAddr result

  var threads: seq[Thread[ThreadData]]
  newSeq(threads, self.numThreads())

  for threadId in 0..<self.numThreads():
    var data = ThreadData(
      a: aPtr,
      bT: bTPtr,
      c: cPtr,
      threadId: threadId,
      numThreads: self.numThreads(),
      n: n
    )
    createThread(threads[threadId], worker, data)

  for thread in threads:
    joinThread(thread)

  return result

method run(self: MatmulBase, iteration_id: int) =
  let nInt = int(self.n)
  let a = matgen(nInt)
  let b = matgen(nInt)
  let c = matmul_parallel(self, a, b)

  let centerIdx = nInt shr 1
  self.resultVal = self.resultVal + checksumF64(c[centerIdx][centerIdx])

method checksum(self: MatmulBase): uint32 =
  self.resultVal

proc newMatmul4T(): Benchmark = Matmul4T()
method numThreads(self: Matmul4T): int = 4
method name(self: Matmul4T): string = "Matmul::T4"

proc newMatmul8T(): Benchmark = Matmul8T()
method numThreads(self: Matmul8T): int = 8
method name(self: Matmul8T): string = "Matmul::T8"

proc newMatmul16T(): Benchmark = Matmul16T()
method numThreads(self: Matmul16T): int = 16
method name(self: Matmul16T): string = "Matmul::T16"

registerBenchmark("Matmul::T4", newMatmul4T)
registerBenchmark("Matmul::T8", newMatmul8T)
registerBenchmark("Matmul::T16", newMatmul16T)
