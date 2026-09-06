package benchmarks

import Benchmark
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import java.util.concurrent.ForkJoinPool

abstract class MatmulBase(
    private val threadCount: Int,
) : Benchmark() {
    protected val n = configInt("n")
    protected lateinit var a: Array<DoubleArray>
    protected lateinit var b: Array<DoubleArray>
    protected var resultVal: UInt = 0u
    private val dispatcher = ForkJoinPool(threadCount).asCoroutineDispatcher()

    companion object {
        private const val CHUNKS_PER_THREAD = 4
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

    private suspend fun forEachRowInParallel(
        n: Int,
        body: (Int) -> Unit,
    ) = coroutineScope {
        val chunks = threadCount * CHUNKS_PER_THREAD
        val rowsPerChunk = (n + chunks - 1) / chunks
        repeat(chunks) { chunkId ->
            launch(dispatcher) {
                val startRow = chunkId * rowsPerChunk
                val endRow = minOf(startRow + rowsPerChunk, n)
                for (i in startRow until endRow) body(i)
            }
        }
    }

    protected suspend fun matmulParallel(
        a: Array<DoubleArray>,
        b: Array<DoubleArray>,
    ): Array<DoubleArray> {
        val n = a.size
        val bT = transpose(b)
        val c = Array(n) { DoubleArray(n) }
        forEachRowInParallel(n) { i ->
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
        return c
    }

    override fun prepare() {
        a = matgen(n)
        b = matgen(n)
        resultVal = 0u
    }

    override fun run(iterationId: Int) {
        val c = if (threadCount == 1) matmulSequential(a, b) else runBlocking { matmulParallel(a, b) }
        resultVal += Helper.checksumF64(c[n / 2][n / 2])
    }

    override fun checksum(): UInt = resultVal
}

class Matmul1T : MatmulBase(1) {
    override fun name(): String = "Matmul::Single"
}

class Matmul4T : MatmulBase(4) {
    override fun name(): String = "Matmul::T4"
}

class Matmul8T : MatmulBase(8) {
    override fun name(): String = "Matmul::T8"
}

class Matmul16T : MatmulBase(16) {
    override fun name(): String = "Matmul::T16"
}
