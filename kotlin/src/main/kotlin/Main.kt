import benchmarks.*
import java.io.File
import java.time.Instant
import java.util.Locale
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    Locale.setDefault(Locale.US)

    Benchmark.registerBenchmark("Pidigits") { Pidigits() }
    Benchmark.registerBenchmark("BinarytreesObj") { BinarytreesObj() }
    Benchmark.registerBenchmark("BinarytreesArena") { BinarytreesArena() }
    Benchmark.registerBenchmark("BrainfuckArray") { BrainfuckArray() }
    Benchmark.registerBenchmark("BrainfuckRecursion") { BrainfuckRecursion() }
    Benchmark.registerBenchmark("Fannkuchredux") { Fannkuchredux() }
    Benchmark.registerBenchmark("Fasta") { Fasta() }
    Benchmark.registerBenchmark("Knuckeotide") { Knuckeotide() }
    Benchmark.registerBenchmark("Mandelbrot") { Mandelbrot() }
    Benchmark.registerBenchmark("Matmul1T") { Matmul1T() }
    Benchmark.registerBenchmark("Matmul4T") { Matmul4T() }
    Benchmark.registerBenchmark("Matmul8T") { Matmul8T() }
    Benchmark.registerBenchmark("Matmul16T") { Matmul16T() }
    Benchmark.registerBenchmark("Nbody") { Nbody() }
    Benchmark.registerBenchmark("RegexDna") { RegexDna() }
    Benchmark.registerBenchmark("Revcomp") { Revcomp() }
    Benchmark.registerBenchmark("Spectralnorm") { Spectralnorm() }
    Benchmark.registerBenchmark("Base64Encode") { Base64Encode() }
    Benchmark.registerBenchmark("Base64Decode") { Base64Decode() }
    Benchmark.registerBenchmark("JsonGenerate") { JsonGenerate() }
    Benchmark.registerBenchmark("JsonParseDom") { JsonParseDom() }
    Benchmark.registerBenchmark("JsonParseMapping") { JsonParseMapping() }
    Benchmark.registerBenchmark("Primes") { Primes() }
    Benchmark.registerBenchmark("Noise") { Noise() }
    Benchmark.registerBenchmark("TextRaytracer") { TextRaytracer() }
    Benchmark.registerBenchmark("NeuralNet") { NeuralNet() }
    Benchmark.registerBenchmark("SortQuick") { SortQuick() }
    Benchmark.registerBenchmark("SortMerge") { SortMerge() }
    Benchmark.registerBenchmark("SortSelf") { SortSelf() }
    Benchmark.registerBenchmark("GraphPathBFS") { GraphPathBFS() }
    Benchmark.registerBenchmark("GraphPathDFS") { GraphPathDFS() }
    Benchmark.registerBenchmark("GraphPathAStar") { GraphPathAStar() }
    Benchmark.registerBenchmark("BufferHashSHA256") { BufferHashSHA256() }
    Benchmark.registerBenchmark("BufferHashCRC32") { BufferHashCRC32() }
    Benchmark.registerBenchmark("CacheSimulation") { CacheSimulation() }
    Benchmark.registerBenchmark("CalculatorAst") { CalculatorAst() }
    Benchmark.registerBenchmark("CalculatorInterpreter") { CalculatorInterpreter() }
    Benchmark.registerBenchmark("GameOfLife") { GameOfLife() }
    Benchmark.registerBenchmark("MazeGenerator") { MazeGenerator() }
    Benchmark.registerBenchmark("AStarPathfinder") { AStarPathfinder() }
    Benchmark.registerBenchmark("Compress::BWTEncode") { BWTEncode() }
    Benchmark.registerBenchmark("Compress::BWTDecode") { BWTDecode() }
    Benchmark.registerBenchmark("Compress::HuffEncode") { HuffEncode() }
    Benchmark.registerBenchmark("Compress::HuffDecode") { HuffDecode() }
    Benchmark.registerBenchmark("Compress::ArithEncode") { ArithEncode() }
    Benchmark.registerBenchmark("Compress::ArithDecode") { ArithDecode() }
    Benchmark.registerBenchmark("Compress::LZWEncode") { LZWEncode() }
    Benchmark.registerBenchmark("Compress::LZWDecode") { LZWDecode() }

    val now = Instant.now().toEpochMilli()
    println("start: $now")

    val configFile =
        when {
            args.isNotEmpty() && args[0].endsWith(".js") -> args[0]
            args.size > 1 && args[1].endsWith(".js") -> args[1]
            else -> null
        }

    val singleBench = args.firstOrNull { !it.endsWith(".js") }

    try {
        Helper.loadConfig(configFile)

        if (Helper.CONFIG.isEmpty()) {
            System.err.println("Warning: No test cases loaded from config file")
            System.err.println("Usage: ./gradlew run --args=\"test.js BrainfuckRecursion\"")
            System.err.println("Or: ./gradlew run --args=\"../run.js\"")
            exitProcess(1)
        }
    } catch (e: Exception) {
        System.err.println("Error loading config file '${configFile ?: "test.js"}': ${e.message}")
        e.printStackTrace()
        exitProcess(1)
    }

    File("/tmp/recompile_marker").writeText("RECOMPILE_MARKER_0")

    Benchmark.all(singleBench)
}
