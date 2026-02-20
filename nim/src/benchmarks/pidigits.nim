import std/[strutils, strformat, streams, math]
import integers
import ../benchmark
import ../helper

{.passL: "-lgmp".}
{.passC: "-I/opt/homebrew/include".}
{.passL: "-L/opt/homebrew/lib".}

type
  Pidigits* = ref object of Benchmark
    nn: int32
    buffer: StringStream

proc newPidigits(): Benchmark =
  Pidigits()

method name(self: Pidigits): string = "Pidigits"

method prepare(self: Pidigits) =
  self.nn = self.config_val("amount").int32
  self.buffer = newStringStream()

method run(self: Pidigits, iteration_id: int) =
  var i = 0
  var k = 0
  var k1 = 1

  var ns = 0'gmp
  var a = 0'gmp
  var n = 1'gmp
  var d = 1'gmp

  while true:
    inc k
    let t = n * 2
    n *= k
    k1 += 2
    a = (a + t) * k1
    d *= k1
    if a >= n:
      let temp = n * 3 + a
      let q = temp // d
      let r = temp mod d
      let u = r + n

      if d > u:
        ns = ns * 10 + q
        inc i
        if i mod 10 == 0:
          var nsStr = $ns
          if nsStr.len < 10:
            nsStr = '0'.repeat(10 - nsStr.len) & nsStr
          self.buffer.write(nsStr)
          self.buffer.write("\t:")
          self.buffer.write($i)
          self.buffer.write("\n")
          ns = 0'gmp

        if i >= self.nn:
          break

        a = (a - (d * q)) * 10
        n *= 10

method checksum(self: Pidigits): uint32 =
  checksum(self.buffer.data)

registerBenchmark("Pidigits", newPidigits)
