package benchmarks

import java.io.FileWriter
import java.util.Locale
import scala.collection.mutable
import scala.util.Using

abstract class Benchmark:
  def run(iterationId: Int): Unit
  def checksum(): Long

  def prepare(): Unit = ()

  def name(): String = this.getClass.getSimpleName

  def warmupIterations(): Long =
    if Helper.CONFIG.has(name()) && Helper.CONFIG.getJSONObject(name()).has("warmup_iterations") then Helper.CONFIG.getJSONObject(name()).getLong("warmup_iterations")
    else
      val iters = iterations()
      math.max((iters * 0.2).toLong, 1L)

  def warmup(): Unit =
    val prepareIters = warmupIterations()
    for i <- 0L until prepareIters do this.run(i.toInt)

  def runAll(): Unit =
    val iters = iterations()
    for i <- 0L until iters do this.run(i.toInt)

  def configVal(fieldName: String): Long = Helper.configI64(this.name(), fieldName)

  def iterations(): Long = configVal("iterations")

  def expectedChecksum(): Long = configVal("checksum")

object Benchmark:
  type Supplier[T] = () => T

  private val benchmarkMap = mutable.Map.empty[String, Supplier[Benchmark]]

  def registerBenchmark(name: String, factory: Supplier[Benchmark]): Unit =
    if benchmarkMap.contains(name) then println(s"Warning: Benchmark with name '$name' already registered. Skipping.")
    else benchmarkMap(name) = factory

  def registerBenchmark(factory: Supplier[Benchmark]): Unit =
    val bench = factory()
    benchmarkMap(bench.name()) = factory

  private def toLower(str: String): String = str.toLowerCase(Locale.US)

  def all(singleBench: String): Unit =
    var summaryTime = 0.0
    var ok = 0
    var fails = 0

    for benchName <- Helper.ORDER do
      val shouldRun =
        if singleBench == null || singleBench.isEmpty then true
        else toLower(benchName).contains(toLower(singleBench))

      if shouldRun then
        benchmarkMap.get(benchName) match
          case Some(factory) =>
            val bench = factory()

            Helper.reset()
            bench.prepare()
            bench.warmup()
            System.gc()

            Helper.reset()

            val startTime = System.nanoTime()
            bench.runAll()
            val timeDelta = (System.nanoTime() - startTime) / 1_000_000_000.0

            System.gc()
            try Thread.sleep(0)
            catch case _: InterruptedException => ()
            System.gc()

            val check = bench.checksum() & 0xffffffffL
            val expected = bench.expectedChecksum()
            print(s"$benchName: ")
            if check == expected then
              print("OK ")
              ok += 1
            else
              print(s"ERR[actual=$check, expected=$expected] ")
              fails += 1

            println(s"in ${Helper.formatTime(timeDelta)}s")
            summaryTime += timeDelta

          case None =>
            println(s"Warning: Benchmark '$benchName' defined in config but not found in code")

    println(f"Summary: ${Helper.formatTime(summaryTime)}s, ${ok + fails}, $ok, $fails")

    if fails > 0 then System.exit(1)
