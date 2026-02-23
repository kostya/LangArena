import std/[math, strutils, os, cpuinfo]
import ../benchmark
import ../helper

proc matgen(n: int): seq[seq[float64]] =
  let tmp = 1.0 / float64(n * n)
  result = newSeq[seq[float64]](n)

  for i in 0..<n:
    var row = newSeq[float64](n)
    for j in 0..<n:
      row[j] = tmp * float64(i - j) * float64(i + j)
    result[i] = row

proc transpose(b: seq[seq[float64]]): seq[seq[float64]] =
  let n = b.len
  result = newSeq[seq[float64]](n)
  for i in 0..<n:
    result[i] = newSeq[float64](n)

  for i in 0..<n:
    for j in 0..<n:
      result[j][i] = b[i][j]

proc matmulSequential(a, b: seq[seq[float64]]): seq[seq[float64]] =
  let n = a.len
  let bT = transpose(b)

  result = newSeq[seq[float64]](n)
  for i in 0..<n:
    result[i] = newSeq[float64](n)

  for i in 0..<n:
    let ai = a[i]
    for j in 0..<n:
      let bj = bT[j]
      var sum = 0.0
      for k in 0..<n:
        sum += ai[k] * bj[k]
      result[i][j] = sum

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

proc matmulParallel(a, b: seq[seq[float64]], numThreads: int): seq[seq[float64]] =
  let n = a.len
  let bT = transpose(b)

  result = newSeq[seq[float64]](n)
  for i in 0..<n:
    result[i] = newSeq[float64](n)

  var aPtr = unsafeAddr a
  var bTPtr = unsafeAddr bT
  var cPtr = unsafeAddr result

  var threads: seq[Thread[ThreadData]]
  newSeq(threads, numThreads)

  for threadId in 0..<numThreads:
    var data = ThreadData(
      a: aPtr,
      bT: bTPtr,
      c: cPtr,
      threadId: threadId,
      numThreads: numThreads,
      n: n
    )
    createThread(threads[threadId], worker, data)

  for thread in threads:
    joinThread(thread)

type
  BaseMatmul* = ref object of Benchmark
    n: int64
    resultVal: uint32
    a: seq[seq[float64]]
    b: seq[seq[float64]]

method prepare(self: BaseMatmul) =
  self.n = self.config_val("n")
  let nInt = int(self.n)
  self.a = matgen(nInt)
  self.b = matgen(nInt)
  self.resultVal = 0

method checksum(self: BaseMatmul): uint32 =
  self.resultVal

type
  Matmul1T* = ref object of BaseMatmul

proc newMatmul1T(): Benchmark =
  Matmul1T()

method name(self: Matmul1T): string = "Matmul::Single"

method run(self: Matmul1T, iteration_id: int) =
  let nInt = int(self.n)
  let c = matmulSequential(self.a, self.b)
  let centerIdx = nInt shr 1
  self.resultVal = self.resultVal + checksumF64(c[centerIdx][centerIdx])

type
  MatmulParallel* = ref object of BaseMatmul
    numThreads: int

method run(self: MatmulParallel, iteration_id: int) =
  let nInt = int(self.n)
  let c = matmulParallel(self.a, self.b, self.numThreads)
  let centerIdx = nInt shr 1
  self.resultVal = self.resultVal + checksumF64(c[centerIdx][centerIdx])

type
  Matmul4T* = ref object of MatmulParallel

proc newMatmul4T(): Benchmark =
  let res = Matmul4T()
  res.numThreads = 4
  res

method name(self: Matmul4T): string = "Matmul::T4"

type
  Matmul8T* = ref object of MatmulParallel

proc newMatmul8T(): Benchmark =
  let res = Matmul8T()
  res.numThreads = 8
  res

method name(self: Matmul8T): string = "Matmul::T8"

type
  Matmul16T* = ref object of MatmulParallel

proc newMatmul16T(): Benchmark =
  let res = Matmul16T()
  res.numThreads = 16
  res

method name(self: Matmul16T): string = "Matmul::T16"

registerBenchmark("Matmul::Single", newMatmul1T)
registerBenchmark("Matmul::T4", newMatmul4T)
registerBenchmark("Matmul::T8", newMatmul8T)
registerBenchmark("Matmul::T16", newMatmul16T)
