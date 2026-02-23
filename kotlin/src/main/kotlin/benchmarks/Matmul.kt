package benchmarks

import Benchmark
import kotlinx.coroutines.*
import java.util.concurrent.Executors

abstract class MatmulBase(
    private val threadCount: Int,
) : Benchmark() {
    protected lateinit var a: Array<DoubleArray>
    protected lateinit var b: Array<DoubleArray>
    protected var n: Long = 0
    protected var resultVal: UInt = 0u

    init {
        n = configVal("n")
    }

    protected fun matgen(n: Int): Array<DoubleArray> {
        val tmp = 1.0 / n / n
        val a = Array(n) { DoubleArray(n) }

        for (i in 0 until n) {
            for (j in 0 until n) {
                a[i][j] = tmp * (i - j) * (i + j)
            }
        }
        return a
    }

    protected fun transpose(b: Array<DoubleArray>): Array<DoubleArray> {
        val n = b.size
        val bT = Array(n) { DoubleArray(n) }

        for (i in 0 until n) {
            for (j in 0 until n) {
                bT[j][i] = b[i][j]
            }
        }
        return bT
    }

    protected fun matmulSequential(
        a: Array<DoubleArray>,
        b: Array<DoubleArray>,
    ): Array<DoubleArray> {
        val n = a.size
        val bT = transpose(b)
        val c = Array(n) { DoubleArray(n) }

        for (i in 0 until n) {
            val ai = a[i]
            val ci = c[i]
            for (j in 0 until n) {
                val bTj = bT[j]
                var sum = 0.0

                for (k in 0 until n) {
                    sum += ai[k] * bTj[k]
                }
                ci[j] = sum
            }
        }
        return c
    }

    protected suspend fun matmulParallel(
        a: Array<DoubleArray>,
        b: Array<DoubleArray>,
    ): Array<DoubleArray> {
        val n = a.size
        val bT = transpose(b)
        val c = Array(n) { DoubleArray(n) }

        val rowsPerThread = (n + threadCount - 1) / threadCount

        coroutineScope {
            val jobs =
                List(threadCount) { threadId ->
                    launch(Dispatchers.Default) {
                        val startRow = threadId * rowsPerThread
                        val endRow = minOf(startRow + rowsPerThread, n)

                        for (i in startRow until endRow) {
                            val ai = a[i]
                            val ci = c[i]

                            for (j in 0 until n) {
                                var sum = 0.0
                                val bTj = bT[j]

                                for (k in 0 until n) {
                                    sum += ai[k] * bTj[k]
                                }

                                ci[j] = sum
                            }
                        }
                    }
                }
            jobs.joinAll()
        }

        return c
    }

    override fun prepare() {
        a = matgen(n.toInt())
        b = matgen(n.toInt())
        resultVal = 0u
    }

    override fun checksum(): UInt = resultVal
}

class Matmul1T : MatmulBase(1) {
    override fun name(): String = "Matmul::Single"

    override fun run(iterationId: Int) {
        val c = matmulSequential(a, b)
        val center = c[(n shr 1).toInt()][(n shr 1).toInt()]
        resultVal += Helper.checksumF64(center)
    }
}

class Matmul4T : MatmulBase(4) {
    override fun name(): String = "Matmul::T4"

    override fun run(iterationId: Int) =
        runBlocking {
            val c = matmulParallel(a, b)
            val center = c[(n shr 1).toInt()][(n shr 1).toInt()]
            resultVal += Helper.checksumF64(center)
        }
}

class Matmul8T : MatmulBase(8) {
    override fun name(): String = "Matmul::T8"

    override fun run(iterationId: Int) =
        runBlocking {
            val c = matmulParallel(a, b)
            val center = c[(n shr 1).toInt()][(n shr 1).toInt()]
            resultVal += Helper.checksumF64(center)
        }
}

class Matmul16T : MatmulBase(16) {
    override fun name(): String = "Matmul::T16"

    override fun run(iterationId: Int) =
        runBlocking {
            val c = matmulParallel(a, b)
            val center = c[(n shr 1).toInt()][(n shr 1).toInt()]
            resultVal += Helper.checksumF64(center)
        }
}
