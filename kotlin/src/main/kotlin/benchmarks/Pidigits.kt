package benchmarks

import Benchmark
import java.math.BigInteger

class Pidigits : Benchmark() {
    private lateinit var output: StringBuilder
    private var nn: Long = 0

    init {
        nn = configVal("amount")
    }

    override fun prepare() {
        output = StringBuilder()
    }

    override fun run(iterationId: Int) {
        var i = 0
        var k = 0
        var ns = BigInteger.ZERO
        var a = BigInteger.ZERO
        var t: BigInteger
        var u: BigInteger
        var k1 = BigInteger.ONE
        var n = BigInteger.ONE
        var d = BigInteger.ONE

        while (true) {
            k += 1
            t = n.shiftLeft(1)
            n = n.multiply(BigInteger.valueOf(k.toLong()))
            k1 = k1.add(BigInteger.valueOf(2))
            a = a.add(t).multiply(k1)
            d = d.multiply(k1)
            if (a >= n) {
                val temp = n.multiply(BigInteger.valueOf(3)).add(a)
                val divResult = temp.divideAndRemainder(d)
                t = divResult[0]
                u = divResult[1].add(n)

                if (d > u) {
                    ns = ns.multiply(BigInteger.TEN).add(t)
                    i += 1
                    if (i % 10 == 0) {
                        output.append(String.format("%010d\t:%d\n", ns.toLong(), i))
                        ns = BigInteger.ZERO
                    }
                    if (i >= nn) break
                    a = a.subtract(d.multiply(t)).multiply(BigInteger.TEN)
                    n = n.multiply(BigInteger.TEN)
                }
            }
        }

        if (ns != BigInteger.ZERO) {
            output.append(String.format("%010d\t:%d\n", ns.toLong(), i))
        }
    }

    override fun checksum(): UInt = Helper.checksum(output.toString())

    override fun name(): String = "Pidigits"
}
