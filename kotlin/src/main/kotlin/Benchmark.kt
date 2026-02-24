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

    open fun configVal(fieldName: String): Long = Helper.configI64(name(), fieldName)

    open fun iterations(): Long = configVal("iterations")

    open fun expectedChecksum(): Long = configVal("checksum")

    fun setTimeDelta(delta: Double) {
        _timeDelta = delta
    }

    companion object {
        private data class NamedBenchmarkFactory(
            val name: String,
            val factory: () -> Benchmark,
        )

        private val benchmarkFactories = mutableListOf<NamedBenchmarkFactory>()

        fun registerBenchmark(
            name: String,
            factory: () -> Benchmark,
        ) {
            if (benchmarkFactories.any { it.name == name }) {
                System.err.println("Warning: Benchmark with name '$name' already registered. Skipping.")
                return
            }
            benchmarkFactories.add(NamedBenchmarkFactory(name, factory))
        }

        fun registerBenchmark(factory: () -> Benchmark) {
            val bench = factory()
            benchmarkFactories.add(NamedBenchmarkFactory(bench.name(), factory))
        }

        fun all(singleBench: String? = null) {
            val results = mutableMapOf<String, Double>()
            var summaryTime = 0.0
            var ok = 0
            var fails = 0

            benchmarkFactories.forEach { factoryInfo ->
                val benchName = factoryInfo.name

                val shouldRun =
                    when {
                        singleBench == null -> true
                        benchName.lowercase().contains(singleBench.lowercase()) -> true
                        else -> false
                    }

                val skipBenchmarks =
                    setOf(
                        "SortBenchmark",
                        "BufferHashBenchmark",
                        "GraphPathBenchmark",
                    )

                if (shouldRun && benchName !in skipBenchmarks) {
                    if (!Helper.CONFIG.has(benchName)) {
                        println("\n[$benchName]: SKIP - no config entry")
                        return@forEach
                    }

                    val bench = factoryInfo.factory()

                    Helper.reset()

                    bench.prepare()
                    bench.warmup()
                    System.gc()

                    Helper.reset()

                    val startTime = System.nanoTime()
                    bench.runAll()
                    val timeDelta2 = (System.nanoTime() - startTime) / 1_000_000_000.0

                    bench.setTimeDelta(timeDelta2)
                    results[benchName] = timeDelta2

                    System.gc()
                    Thread.sleep(1)
                    System.gc()

                    print("$benchName: ")
                    if (bench.checksum().toLong() == bench.expectedChecksum()) {
                        print("OK ")
                        ok++
                    } else {
                        print("ERR[actual=${bench.checksum()}, expected=${bench.expectedChecksum()}] ")
                        fails++
                    }

                    print("in %.3fs\n".format(timeDelta2))
                    summaryTime += timeDelta2
                } else if (shouldRun) {
                    println("\n[$benchName]: SKIP - no config entry")
                }
            }

            try {
                java.io.File("/tmp/results.js").writeText(
                    results.entries.joinToString(
                        ", ",
                        "{",
                        "}",
                    ) { "\"${it.key}\": ${it.value}" },
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
