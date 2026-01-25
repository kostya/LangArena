package benchmarks
import Benchmark

import kotlinx.coroutines.*
import java.util.concurrent.Executors

class Matmul4T : Benchmark() {
    private var n: Int = 0
    private var resultValue: Long = 0L
    
    init {
        n = iterations
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
    
    private fun matmulParallel(a: Array<DoubleArray>, b: Array<DoubleArray>): Array<DoubleArray> {
        val size = a.size
        
        // Транспонируем b (последовательно)
        val bT = Array(size) { DoubleArray(size) }
        for (i in 0 until size) {
            for (j in 0 until size) {
                bT[j][i] = b[i][j]
            }
        }
        
        // Умножение матриц (параллельно)
        val c = Array(size) { DoubleArray(size) }
        
        // Используем фиксированный пул потоков
        val numThreads = 4
        val executor = Executors.newFixedThreadPool(numThreads)
        val scope = CoroutineScope(executor.asCoroutineDispatcher())
        
        runBlocking {
            val jobs = mutableListOf<Job>()
            val rowsPerThread = (size + 3) / numThreads
            
            for (threadId in 0 until numThreads) {
                val job = scope.launch {
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
            
            // Ждем завершения всех корутин
            jobs.joinAll()
        }
        
        executor.shutdown()
        return c
    }
    
    override fun run() {
        val a = matgen(n)
        val b = matgen(n)
        val c = matmulParallel(a, b)
        val center = c[n shr 1][n shr 1]
        resultValue = Helper.checksumF64(center).toLong()
    }
    
    override val result: Long
        get() = resultValue
}
