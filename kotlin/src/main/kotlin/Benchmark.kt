abstract class Benchmark {
    protected var _timeDelta = 0.0

    abstract fun run(iterationId: Int)  
    abstract fun checksum(): UInt  

    open fun prepare() {}

    abstract fun name(): String

    open fun warmupIterations(): Long {
        val iters = iterations()
        return kotlin.math.max((iters * 0.2).toLong(), 1L)
    }

    open fun warmup() {
        val prepareIters = warmupIterations()
        for (i in 0 until prepareIters) {
            this.run(i.toInt())
        }
    }

    open fun runAll() {
        val iters = iterations()
        for (i in 0 until iters) {
            this.run(i.toInt())
        }
    }

    open fun configVal(fieldName: String): Long {
        return Helper.configI64(name(), fieldName)
    }

    open fun iterations(): Long {
        return configVal("iterations")
    }

    open fun expectedChecksum(): Long {
        return configVal("checksum")
    }

    fun setTimeDelta(delta: Double) { _timeDelta = delta }

    companion object {
        private val benchmarkFactories = mutableListOf<() -> Benchmark>()

        fun registerBenchmark(factory: () -> Benchmark) {
            benchmarkFactories.add(factory)
        }

        fun all(singleBench: String? = null) {
            val results = mutableMapOf<String, Double>()
            var summaryTime = 0.0
            var ok = 0
            var fails = 0

            benchmarkFactories.forEach { factory ->
                val bench = factory()
                val className = bench.name()

                val shouldRun = when {
                    singleBench == null -> true
                    className.lowercase().contains(singleBench.lowercase()) -> true
                    else -> false
                }

                if (shouldRun && 
                    className != "SortBenchmark" && 
                    className != "BufferHashBenchmark" && 
                    className != "GraphPathBenchmark") {

                    print("$className: ")

                    Helper.reset()

                    bench.prepare()
                    bench.warmup()

                    Helper.reset()

                    val startTime = System.nanoTime()
                    bench.runAll()  
                    val timeDelta2 = (System.nanoTime() - startTime) / 1_000_000_000.0

                    bench.setTimeDelta(timeDelta2)
                    results[className] = timeDelta2

                    System.gc()
                    Thread.sleep(1)  
                    System.gc()

                    if (bench.checksum().toLong() == bench.expectedChecksum()) {
                        print("OK ")
                        ok++
                    } else {
                        print("ERR[actual=${bench.checksum()}, expected=${bench.expectedChecksum()}] ")
                        fails++
                    }

                    print("in %.3fs\n".format(timeDelta2))
                    summaryTime += timeDelta2
                }
            }

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