import std/[math, strutils]
import ../benchmark
import ../helper

type
  Mandelbrot* = ref object of Benchmark
    w, h: int64
    resultBin: seq[byte]

proc newMandelbrot(): Benchmark =
  Mandelbrot()

method name(self: Mandelbrot): string = "CLBG::Mandelbrot"

method prepare(self: Mandelbrot) =
  self.w = self.config_val("w")
  self.h = self.config_val("h")
  self.resultBin = @[]

method run(self: Mandelbrot, iteration_id: int) =
  const ITER = 50
  const LIMIT = 2.0

  let header = "P4\n" & $self.w & " " & $self.h & "\n"
  for c in header:
    self.resultBin.add(byte(c))

  var bitNum = 0
  var byteAcc: byte = 0

  for y in 0..<self.h.int:
    for x in 0..<self.w.int:
      let tmpX = float(x)
      let tmpY = float(y)
      let tmpW = float(self.w)
      let tmpH = float(self.h)

      let cr = 2.0 * tmpX / tmpW - 1.5
      let ci = 2.0 * tmpY / tmpH - 1.0

      var zr = 0.0
      var zi = 0.0
      var tr = 0.0
      var ti = 0.0

      var i = 0
      while i < ITER and tr + ti <= LIMIT * LIMIT:
        zi = 2.0 * zr * zi + ci
        zr = tr - ti + cr
        tr = zr * zr
        ti = zi * zi
        inc i

      byteAcc = byteAcc shl 1
      if tr + ti <= LIMIT * LIMIT:
        byteAcc = byteAcc or 0x01
      inc bitNum

      if bitNum == 8:
        self.resultBin.add(byteAcc)
        byteAcc = 0
        bitNum = 0
      elif x == self.w.int - 1:
        let shiftAmount = 8 - (self.w.int mod 8)
        byteAcc = byteAcc shl shiftAmount
        self.resultBin.add(byteAcc)
        byteAcc = 0
        bitNum = 0

method checksum(self: Mandelbrot): uint32 =
  checksum(self.resultBin)

registerBenchmark("CLBG::Mandelbrot", newMandelbrot)
