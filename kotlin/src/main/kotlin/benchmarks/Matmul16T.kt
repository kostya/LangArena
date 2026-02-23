package benchmarks
import Benchmark
import kotlinx.coroutines.*
import java.util.concurrent.Executors

class Matmul16T : Benchmark() {
    private var n: Long = 0
    private var resultVal: UInt = 0u

    init {
        n = configVal("n")
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

    private fun matmulParallel(
        a: Array<DoubleArray>,
        b: Array<DoubleArray>,
    ): Array<DoubleArray> {
        val size = a.size

        val bT = Array(size) { DoubleArray(size) }
        for (i in 0 until size) {
            for (j in 0 until size) {
                bT[j][i] = b[i][j]
            }
        }

        val c = Array(size) { DoubleArray(size) }

        val numThreads = 16
        val executor = Executors.newFixedThreadPool(numThreads)
        val scope = CoroutineScope(executor.asCoroutineDispatcher())

        runBlocking {
            val jobs = mutableListOf<Job>()
            val rowsPerThread = (size + 3) / numThreads

            for (threadId in 0 until numThreads) {
                val job =
                    scope.launch {
                        val startRow = threadId * rowsPerThread
                        val endRow = minOf(startRow + rowsPerThread, size)

                        for (i in startRow until endRow) {
                            val ai = a[i]
                            val ci = c[i]

                            for (j in 0 until size) {
                                var sum = 0.0
                                val bTj = bT[j]

                                for (k in 0 until size) {
                                    sum += ai[k] * bTj[k]
                                }

                                ci[j] = sum
                            }
                        }
                    }
                jobs.add(job)
            }

            jobs.joinAll()
        }

        executor.shutdown()
        return c
    }

    override fun run(iterationId: Int) {
        val a = matgen(n.toInt())
        val b = matgen(n.toInt())
        val c = matmulParallel(a, b)
        val center = c[(n shr 1).toInt()][(n shr 1).toInt()]
        resultVal += Helper.checksumF64(center)
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "Matmul::T16"
}
