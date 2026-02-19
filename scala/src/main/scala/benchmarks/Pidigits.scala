package benchmarks

import java.math.BigInteger
import scala.util.Using

class Pidigits extends Benchmark:
  private val nn: Int = configVal("amount").toInt
  private val result = new StringBuilder()

  override def name(): String = "Pidigits"

  override def run(iterationId: Int): Unit =
    var i = 0
    var k = 0
    var ns = BigInteger.ZERO
    var a = BigInteger.ZERO
    var k1 = 1
    var n = BigInteger.ONE
    var d = BigInteger.ONE

    while i < nn do
      k += 1

      val t = n.shiftLeft(1)
      n = n.multiply(BigInteger.valueOf(k.toLong))
      k1 += 2
      a = a.add(t).multiply(BigInteger.valueOf(k1.toLong))
      d = d.multiply(BigInteger.valueOf(k1.toLong))

      if a.compareTo(n) >= 0 then
        val divResult = n
          .multiply(BigInteger.valueOf(3))
          .add(a)
          .divideAndRemainder(d)
        val digit = divResult(0).intValue()
        val u = divResult(1).add(n)

        if d.compareTo(u) > 0 then
          ns = ns.multiply(BigInteger.TEN).add(BigInteger.valueOf(digit.toLong))
          i += 1

          if i % 10 == 0 then

            result.append(String.format("%010d\t:%d%n", ns.longValue(), i))
            ns = BigInteger.ZERO

          if i >= nn then ()

          a = a
            .subtract(d.multiply(BigInteger.valueOf(digit.toLong)))
            .multiply(BigInteger.TEN)
          n = n.multiply(BigInteger.TEN)

    if ns.compareTo(BigInteger.ZERO) > 0 then

      result.append(String.format(s"%0${nn % 10}d\t:%d%n", ns.longValue(), nn))

  override def checksum(): Long =
    Helper.checksum(result.toString()) & 0xffffffffL
