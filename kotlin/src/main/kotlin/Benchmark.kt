// Файл: src/main/kotlin/Benchmark.kt
// НЕ в пакете benchmarks!

abstract class Benchmark {
    abstract fun run()  // this is only method which time measured
    abstract val result: Long

    open fun prepare() {
        // optional override
    }

    val iterations: Int
        get() = Helper.INPUT[this::class.simpleName ?: ""]?.toIntOrNull() ?: 0

    companion object {
        private val benchmarkFactories = mutableListOf<() -> Benchmark>()

        fun registerBenchmark(factory: () -> Benchmark) {
            benchmarkFactories.add(factory)
        }

        fun run(singleBench: String? = null) {
            val results = mutableMapOf<String, Double>()
            var summaryTime = 0.0
            var ok = 0
            var fails = 0

            benchmarkFactories.forEach { factory ->
                val bench = factory()
                val className = bench::class.simpleName ?: ""
                
                if ((singleBench == null || singleBench == className) && 
                    className != "SortBenchmark" && 
                    className != "BufferHashBenchmark" && 
                    className != "GraphPathBenchmark") {
                    
                    print("$className: ")
                    
                    Helper.reset()
                    
                    bench.prepare()
                    
                    val startTime = System.nanoTime()
                    bench.run()
                    val timeDelta = (System.nanoTime() - startTime) / 1_000_000_000.0
                    
                    results[className] = timeDelta
                    
                    System.gc()
                    Thread.sleep(0) // context switch
                    System.gc()
                    
                    if (bench.result == Helper.EXPECT[className]) {
                        print("OK ")
                        ok++
                    } else {
                        print("ERR[actual=${bench.result}, expected=${Helper.EXPECT[className]}] ")
                        fails++
                    }
                    
                    print("in %.3fs\n".format(timeDelta))
                    summaryTime += timeDelta
                }
            }

            // Write results to file
            try {
                java.io.File("/tmp/results.js").writeText(
                    results.entries.joinToString(
                        ", ",
                        "{",
                        "}"
                    ) { "\"${it.key}\": ${it.value}" }
                )
            } catch (e: Exception) {
                System.err.println("Failed to write results: ${e.message}")
            }
            
            println("Summary: %.4fs, %d, %d, %d".format(summaryTime, ok + fails, ok, fails))
            
            if (fails > 0) {
                kotlin.system.exitProcess(1)
            }
        }
    }
}