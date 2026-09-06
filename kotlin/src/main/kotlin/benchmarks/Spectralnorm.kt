package benchmarks

import Benchmark
import kotlin.math.sqrt

class Spectralnorm : Benchmark() {
    private val sizeVal = configInt("size")
    private var u = DoubleArray(sizeVal) { 1.0 }
    private var v = DoubleArray(sizeVal) { 1.0 }

    private fun evalA(
        i: Int,
        j: Int,
    ): Double = 1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0)

    private fun evalATimesU(u: DoubleArray): DoubleArray =
        DoubleArray(u.size) { i ->
            var sum = 0.0
            for (j in u.indices) {
                sum += evalA(i, j) * u[j]
            }
            sum
        }

    private fun evalAtTimesU(u: DoubleArray): DoubleArray =
        DoubleArray(u.size) { i ->
            var sum = 0.0
            for (j in u.indices) {
                sum += evalA(j, i) * u[j]
            }
            sum
        }

    private fun evalAtATimesU(u: DoubleArray): DoubleArray = evalAtTimesU(evalATimesU(u))

    override fun run(iterationId: Int) {
        v = evalAtATimesU(u)
        u = evalAtATimesU(v)
    }

    override fun checksum(): UInt {
        var vBv = 0.0
        var vv = 0.0
        for (i in 0 until sizeVal) {
            vBv += u[i] * v[i]
            vv += v[i] * v[i]
        }
        return Helper.checksumF64(sqrt(vBv / vv))
    }

    override fun name(): String = "CLBG::Spectralnorm"
}
