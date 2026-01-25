package benchmarks

import Benchmark

class Matmul : Benchmark() {
    private var n: Int = 0
    private var resultValue: Long = 0L
    
    init {
        n = iterations
    }
    
    private fun matmul(a: Array<DoubleArray>, b: Array<DoubleArray>): Array<DoubleArray> {
        val m = a.size
        val n = a[0].size
        val p = b[0].size
        
        // transpose
        val b2 = Array(p) { DoubleArray(n) }
        for (i in 0 until n) {
            for (j in 0 until p) {
                b2[j][i] = b[i][j]
            }
        }
        
        // multiplication
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
    
    override fun run() {
        val a = matgen(n)
        val b = matgen(n)
        val c = matmul(a, b)
        val center = c[n shr 1][n shr 1]
        resultValue = Helper.checksumF64(center).toLong()
    }
    
    override val result: Long
        get() = resultValue
}