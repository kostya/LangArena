package benchmarks

import Benchmark
import kotlin.math.sqrt

class Spectralnorm : Benchmark() {
    private var sizeVal: Long = 0
    private lateinit var u: DoubleArray
    private lateinit var v: DoubleArray

    init {
        sizeVal = configVal("size")
        u = DoubleArray(sizeVal.toInt()) { 1.0 }
        v = DoubleArray(sizeVal.toInt()) { 1.0 }
    }

    private fun evalA(i: Int, j: Int): Double {
        return 1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0)
    }

    private fun evalATimesU(u: DoubleArray): DoubleArray {
        return DoubleArray(u.size) { i ->
            var v = 0.0
            for ((j, value) in u.withIndex()) {
                v += evalA(i, j) * value
            }
            v
        }
    }

    private fun evalAtTimesU(u: DoubleArray): DoubleArray {
        return DoubleArray(u.size) { i ->
            var v = 0.0
            for ((j, value) in u.withIndex()) {
                v += evalA(j, i) * value
            }
            v
        }
    }

    private fun evalAtATimesU(u: DoubleArray): DoubleArray {
        return evalAtTimesU(evalATimesU(u))
    }

    override fun run(iterationId: Int) {
        v = evalAtATimesU(u)
        u = evalAtATimesU(v)
    }

    override fun checksum(): UInt {
        var vBv = 0.0
        var vv = 0.0
        for (i in 0 until sizeVal.toInt()) {
            vBv += u[i] * v[i]
            vv += v[i] * v[i]
        }
        return Helper.checksumF64(sqrt(vBv / vv))
    }

    override fun name(): String = "Spectralnorm"
}