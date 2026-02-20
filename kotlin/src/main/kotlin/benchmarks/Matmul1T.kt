package benchmarks

import Benchmark

class Matmul1T : Benchmark() {
    private var n: Long = 0
    private var resultVal: UInt = 0u

    init {
        n = configVal("n")
    }

    private fun matmul(
        a: Array<DoubleArray>,
        b: Array<DoubleArray>,
    ): Array<DoubleArray> {
        val m = a.size
        val n = a[0].size
        val p = b[0].size

        val b2 = Array(p) { DoubleArray(n) }
        for (i in 0 until n) {
            for (j in 0 until p) {
                b2[j][i] = b[i][j]
            }
        }

        val c = Array(m) { DoubleArray(p) }
        for (i in 0 until m) {
            val ai = a[i]
            val ci = c[i]
            for (j in 0 until p) {
                var s = 0.0
                val b2j = b2[j]
                for (k in 0 until n) {
                    s += ai[k] * b2j[k]
                }
                ci[j] = s
            }
        }
        return c
    }

    private fun matgen(n: Int): Array<DoubleArray> {
        val tmp = 1.0 / n / n
        val a = Array(n) { DoubleArray(n) }

        for (i in 0 until n) {
            for (j in 0 until n) {
                a[i][j] = tmp * (i - j) * (i + j)
            }
        }
        return a
    }

    override fun run(iterationId: Int) {
        val a = matgen(n.toInt())
        val b = matgen(n.toInt())
        val c = matmul(a, b)
        val center = c[(n shr 1).toInt()][(n shr 1).toInt()]
        resultVal += Helper.checksumF64(center)
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "Matmul1T"
}
