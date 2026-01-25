package benchmarks

import Benchmark
import java.math.BigInteger

class Pidigits : Benchmark() {
    private lateinit var output: StringBuilder
    private var nn: Int = 0
    
    init {
        nn = iterations
    }
    
    override fun prepare() {
        output = StringBuilder()
    }
    
    override fun run() {
        var i = 0
        var k = 0
        var ns = BigInteger.ZERO
        var a = BigInteger.ZERO
        var t: BigInteger
        var u: BigInteger
        var k1 = BigInteger.ONE  // Используем BigInteger для k1 тоже!
        var n = BigInteger.ONE
        var d = BigInteger.ONE

        while (true) {
            k += 1
            
            // t = n << 1  (n * 2)
            t = n.shiftLeft(1)  // ТОЧНО как в Crystal: сдвиг BigInt
            
            // n *= k
            n = n.multiply(BigInteger.valueOf(k.toLong()))
            
            // k1 += 2
            k1 = k1.add(BigInteger.valueOf(2))
            
            // a = (a + t) * k1
            a = a.add(t).multiply(k1)
            
            // d *= k1
            d = d.multiply(k1)
            
            if (a >= n) {
                // t, u = (n * 3 + a).divmod(d)
                val temp = n.multiply(BigInteger.valueOf(3)).add(a)
                val divResult = temp.divideAndRemainder(d)
                t = divResult[0]  // t остаётся BigInteger
                u = divResult[1].add(n)  // u += n
                
                if (d > u) {
                    // ns = ns * 10 + t
                    ns = ns.multiply(BigInteger.TEN).add(t)
                    
                    i += 1
                    
                    if (i % 10 == 0) {
                        // Форматируем как в Crystal: %010d для 64-битного
                        output.append(String.format("%010d\t:%d\n", ns.toLong(), i))
                        ns = BigInteger.ZERO
                    }
                    
                    if (i >= nn) break
                    
                    // a = (a - (d * t)) * 10
                    a = a.subtract(d.multiply(t)).multiply(BigInteger.TEN)
                    
                    // n *= 10
                    n = n.multiply(BigInteger.TEN)
                }
            }
        }
        
        // Последняя группа цифр
        if (ns != BigInteger.ZERO) {
            output.append(String.format("%010d\t:%d\n", ns.toLong(), i))
        }
    }
    
    override val result: Long
        get() = Helper.checksum(output.toString()).toLong()
}