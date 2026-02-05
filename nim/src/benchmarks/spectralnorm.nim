import std/[math]
import ../benchmark
import ../helper

type
  Spectralnorm* = ref object of Benchmark
    sizeVal: int64
    u: seq[float]
    v: seq[float]

proc newSpectralnorm(): Benchmark =
  Spectralnorm()

method name(self: Spectralnorm): string = "Spectralnorm"

method prepare(self: Spectralnorm) =
  self.sizeVal = self.config_val("size")
  self.u = newSeq[float](self.sizeVal)
  self.v = newSeq[float](self.sizeVal)
  for i in 0..<self.sizeVal:
    self.u[i] = 1.0
    self.v[i] = 1.0

proc evalA(i, j: int): float =
  1.0 / ((float(i) + float(j)) * (float(i) + float(j) + 1.0) / 2.0 + float(i) + 1.0)

proc evalATimesU(u: seq[float]): seq[float] =
  result = newSeq[float](u.len)
  for i in 0..<u.len:
    var sum = 0.0
    for j in 0..<u.len:
      sum += evalA(i, j) * u[j]
    result[i] = sum

proc evalAtTimesU(u: seq[float]): seq[float] =
  result = newSeq[float](u.len)
  for i in 0..<u.len:
    var sum = 0.0
    for j in 0..<u.len:
      sum += evalA(j, i) * u[j]
    result[i] = sum

proc evalAtATimesU(u: seq[float]): seq[float] =
  evalAtTimesU(evalATimesU(u))

method run(self: Spectralnorm, iteration_id: int) =
  self.v = evalAtATimesU(self.u)
  self.u = evalAtATimesU(self.v)

method checksum(self: Spectralnorm): uint32 =
  var vBv = 0.0
  var vv = 0.0
  for i in 0..<self.sizeVal:
    vBv += self.u[i] * self.v[i]
    vv += self.v[i] * self.v[i]

  checksumF64(sqrt(vBv / vv))

registerBenchmark("Spectralnorm", newSpectralnorm)