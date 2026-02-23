package benchmarks

import java.io.FileWriter
import java.time.Instant
import scala.util.Using

object Main:
  def main(args: Array[String]): Unit =

    Benchmark.registerBenchmark("Pidigits", () => new Pidigits())
    Benchmark.registerBenchmark("BinarytreesObj", () => new BinarytreesObj())
    Benchmark.registerBenchmark("BinarytreesArena", () => new BinarytreesArena())
    Benchmark.registerBenchmark("BrainfuckArray", () => new BrainfuckArray())
    Benchmark.registerBenchmark("BrainfuckRecursion", () => new BrainfuckRecursion())
    Benchmark.registerBenchmark("Fannkuchredux", () => new Fannkuchredux())
    Benchmark.registerBenchmark("Fasta", () => new Fasta())
    Benchmark.registerBenchmark("Knuckeotide", () => new Knuckeotide())
    Benchmark.registerBenchmark("Mandelbrot", () => new Mandelbrot())
    Benchmark.registerBenchmark("Matmul1T", () => new Matmul1T())
    Benchmark.registerBenchmark("Matmul4T", () => new Matmul4T())
    Benchmark.registerBenchmark("Matmul8T", () => new Matmul8T())
    Benchmark.registerBenchmark("Matmul16T", () => new Matmul16T())
    Benchmark.registerBenchmark("Nbody", () => new Nbody())
    Benchmark.registerBenchmark("RegexDna", () => new RegexDna())
    Benchmark.registerBenchmark("Revcomp", () => new Revcomp())
    Benchmark.registerBenchmark("Spectralnorm", () => new Spectralnorm())
    Benchmark.registerBenchmark("Base64Encode", () => new Base64Encode())
    Benchmark.registerBenchmark("Base64Decode", () => new Base64Decode())
    Benchmark.registerBenchmark("JsonGenerate", () => new JsonGenerate())
    Benchmark.registerBenchmark("JsonParseDom", () => new JsonParseDom())
    Benchmark.registerBenchmark("JsonParseMapping", () => new JsonParseMapping())
    Benchmark.registerBenchmark("Primes", () => new Primes())
    Benchmark.registerBenchmark("Noise", () => new Noise())
    Benchmark.registerBenchmark("TextRaytracer", () => new TextRaytracer())
    Benchmark.registerBenchmark("NeuralNet", () => new NeuralNet())
    Benchmark.registerBenchmark("SortQuick", () => new SortQuick())
    Benchmark.registerBenchmark("SortMerge", () => new SortMerge())
    Benchmark.registerBenchmark("SortSelf", () => new SortSelf())
    Benchmark.registerBenchmark("GraphPathBFS", () => new GraphPathBFS())
    Benchmark.registerBenchmark("GraphPathDFS", () => new GraphPathDFS())
    Benchmark.registerBenchmark("GraphPathAStar", () => new GraphPathAStar())
    Benchmark.registerBenchmark("BufferHashSHA256", () => new BufferHashSHA256())
    Benchmark.registerBenchmark("BufferHashCRC32", () => new BufferHashCRC32())
    Benchmark.registerBenchmark("CacheSimulation", () => new CacheSimulation())
    Benchmark.registerBenchmark("CalculatorAst", () => new CalculatorAst())
    Benchmark.registerBenchmark("CalculatorInterpreter", () => new CalculatorInterpreter())
    Benchmark.registerBenchmark("GameOfLife", () => new GameOfLife())
    Benchmark.registerBenchmark("MazeGenerator", () => new MazeGenerator())
    Benchmark.registerBenchmark("AStarPathfinder", () => new AStarPathfinder())
    Benchmark.registerBenchmark("Compress::BWTEncode", () => new BWTEncode())
    Benchmark.registerBenchmark("Compress::BWTDecode", () => new BWTDecode())
    Benchmark.registerBenchmark("Compress::HuffEncode", () => new HuffEncode())
    Benchmark.registerBenchmark("Compress::HuffDecode", () => new HuffDecode())
    Benchmark.registerBenchmark("Compress::ArithEncode", () => new ArithEncode())
    Benchmark.registerBenchmark("Compress::ArithDecode", () => new ArithDecode())
    Benchmark.registerBenchmark("Compress::LZWEncode", () => new LZWEncode())
    Benchmark.registerBenchmark("Compress::LZWDecode", () => new LZWDecode())

    val now = Instant.now().toEpochMilli
    println(s"start: $now")

    var configFile: String = null
    var singleBench: String = null

    for arg <- args do
      if arg.endsWith(".js") then configFile = arg
      else singleBench = arg

    try
      Helper.loadConfig(configFile)

      if Helper.CONFIG.length() == 0 then
        System.err.println("Warning: No test cases loaded from config file")
        System.err.println("Usage: mvn exec:java -Dexec.args=\"test.js BrainfuckRecursion\"")
        System.err.println("Or: mvn exec:java -Dexec.args=\"../run.js\"")
        System.exit(1)
    catch
      case e: Exception =>
        System.err.println(s"Error loading config file '${Option(configFile).getOrElse("test.js")}': ${e.getMessage}")
        e.printStackTrace()
        System.exit(1)

    Using.resource(new FileWriter("/tmp/recompile_marker")): writer =>
      writer.write("RECOMPILE_MARKER_0")

    Benchmark.all(singleBench)
    System.exit(0)
