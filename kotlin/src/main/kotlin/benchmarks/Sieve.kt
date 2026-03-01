package benchmarks

import Benchmark
import kotlin.math.sqrt

class Sieve : Benchmark() {
    private var limit: Long = 0
    private var checksum: UInt = 0u

    init {
        limit = configVal("limit")
    }

    override fun run(iterationId: Int) {
        val lim = limit.toInt()
        val primes = ByteArray(lim + 1) { 1 }
        primes[0] = 0
        primes[1] = 0

        val sqrtLimit = sqrt(lim.toDouble()).toInt()

        for (p in 2..sqrtLimit) {
            if (primes[p] == 1.toByte()) {
                var multiple = p * p
                while (multiple <= lim) {
                    primes[multiple] = 0
                    multiple += p
                }
            }
        }

        var lastPrime = 2
        var count = 1

        var n = 3
        while (n <= lim) {
            if (primes[n] == 1.toByte()) {
                lastPrime = n
                count++
            }
            n += 2
        }

        checksum = (checksum.toLong() + lastPrime + count).toUInt() and 0xFFFFFFFFu
    }

    override fun checksum(): UInt = checksum

    override fun name(): String = "Etc::Sieve"
}
