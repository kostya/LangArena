package benchmarks

import Benchmark

class Fannkuchredux : Benchmark() {
    private var n: Long = 0
    private var resultVal: UInt = 0u

    init {
        n = configVal("n")
    }

    private data class Result(
        val checksum: Int,
        val maxFlipsCount: Int,
    )

    private fun fannkuchredux(n: Int): Result {
        val perm1 = IntArray(32) { it }
        val perm = IntArray(32)
        val count = IntArray(32)
        var maxFlipsCount = 0
        var permCount = 0
        var checksum = 0
        var r = n

        while (true) {
            while (r > 1) {
                count[r - 1] = r
                r -= 1
            }

            System.arraycopy(perm1, 0, perm, 0, n)

            var flipsCount = 0
            var k = perm[0]

            while (k != 0) {
                val k2 = (k + 1) shr 1
                for (i in 0 until k2) {
                    val j = k - i
                    val temp = perm[i]
                    perm[i] = perm[j]
                    perm[j] = temp
                }
                flipsCount += 1
                k = perm[0]
            }

            if (flipsCount > maxFlipsCount) {
                maxFlipsCount = flipsCount
            }

            checksum += if (permCount % 2 == 0) flipsCount else -flipsCount

            while (true) {
                if (r == n) {
                    return Result(checksum, maxFlipsCount)
                }

                val perm0 = perm1[0]
                for (i in 0 until r) {
                    val j = i + 1
                    val temp = perm1[i]
                    perm1[i] = perm1[j]
                    perm1[j] = temp
                }

                perm1[r] = perm0
                count[r] -= 1
                val cntr = count[r]
                if (cntr > 0) break
                r += 1
            }
            permCount += 1
        }
    }

    override fun run(iterationId: Int) {
        val (a, b) = fannkuchredux(n.toInt())
        resultVal += (a * 100 + b).toUInt()
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "CLBG::Fannkuchredux"
}
