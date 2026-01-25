package benchmarks

import Benchmark
import kotlin.math.sqrt

class Spectralnorm : Benchmark() {
    private var n: Int = 0
    private var resultValue: Long = 0L
    
    init {
        n = iterations
    }
    
    private fun evalA(i: Int, j: Int): Double {
        return 1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0)
    }
    
    private fun evalATimesU(u: DoubleArray): DoubleArray {
        return DoubleArray(u.size) { i ->
            var v = 0.0
            for (j in u.indices) {
                v += evalA(i, j) * u[j]
            }
            v
        }
    }
    
    private fun evalAtTimesU(u: DoubleArray): DoubleArray {
        return DoubleArray(u.size) { i ->
            var v = 0.0
            for (j in u.indices) {
                v += evalA(j, i) * u[j]
            }
            v
        }
    }
    
    private fun evalAtATimesU(u: DoubleArray): DoubleArray {
        return evalAtTimesU(evalATimesU(u))
    }
    
    override fun run() {
        var u = DoubleArray(n) { 1.0 }
        var v = DoubleArray(n) { 1.0 }
        
        repeat(10) {
            v = evalAtATimesU(u)
            u = evalAtATimesU(v)
        }
        
        var vBv = 0.0
        var vv = 0.0
        for (i in 0 until n) {
            vBv += u[i] * v[i]
            vv += v[i] * v[i]
        }
        
        val resultDouble = sqrt(vBv / vv)
        resultValue = Helper.checksumF64(resultDouble).toLong()
    }
    
    override val result: Long
        get() = resultValue
}