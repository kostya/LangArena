package benchmarks

import java.io.ByteArrayOutputStream

class Mandelbrot extends Benchmark:
  private val ITER = 50
  private val LIMIT = 2.0

  private var w: Int = 0
  private var h: Int = 0
  private val result = new ByteArrayOutputStream()

  override def name(): String = "CLBG::Mandelbrot"

  override def prepare(): Unit =
    w = configVal("w").toInt
    h = configVal("h").toInt

  override def run(iterationId: Int): Unit =
    result.write(s"P4\n$w $h\n".getBytes)

    var bitNum = 0
    var byteAcc: Byte = 0

    var y = 0
    while y < h do
      var x = 0
      while x < w do
        var zr = 0.0
        var zi = 0.0
        var tr = 0.0
        var ti = 0.0
        val cr = (2.0 * x / w - 1.5)
        val ci = (2.0 * y / h - 1.0)

        var i = 0
        while i < ITER && (tr + ti <= LIMIT * LIMIT) do
          zi = 2.0 * zr * zi + ci
          zr = tr - ti + cr
          tr = zr * zr
          ti = zi * zi
          i += 1

        byteAcc = (byteAcc << 1).toByte
        if tr + ti <= LIMIT * LIMIT then byteAcc = (byteAcc | 0x01).toByte
        bitNum += 1

        if bitNum == 8 then
          result.write(byteAcc)
          byteAcc = 0
          bitNum = 0
        else if x == w - 1 then
          byteAcc = (byteAcc << (8 - (w % 8))).toByte
          result.write(byteAcc)
          byteAcc = 0
          bitNum = 0

        x += 1
      y += 1

  override def checksum(): Long =
    Helper.checksum(result.toByteArray())
