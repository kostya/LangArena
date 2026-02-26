import benchmarks.*
import java.io.File
import java.time.Instant
import java.util.Locale
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    Locale.setDefault(Locale.US)

    Benchmark.registerBenchmark("CLBG::Pidigits") { Pidigits() }
    Benchmark.registerBenchmark("Binarytrees::Obj") { BinarytreesObj() }
    Benchmark.registerBenchmark("Binarytrees::Arena") { BinarytreesArena() }
    Benchmark.registerBenchmark("Brainfuck::Array") { BrainfuckArray() }
    Benchmark.registerBenchmark("Brainfuck::Recursion") { BrainfuckRecursion() }
    Benchmark.registerBenchmark("CLBG::Fannkuchredux") { Fannkuchredux() }
    Benchmark.registerBenchmark("CLBG::Fasta") { Fasta() }
    Benchmark.registerBenchmark("CLBG::Knuckeotide") { Knuckeotide() }
    Benchmark.registerBenchmark("CLBG::Mandelbrot") { Mandelbrot() }
    Benchmark.registerBenchmark("Matmul::Single") { Matmul1T() }
    Benchmark.registerBenchmark("Matmul::T4") { Matmul4T() }
    Benchmark.registerBenchmark("Matmul::T8") { Matmul8T() }
    Benchmark.registerBenchmark("Matmul::T16") { Matmul16T() }
    Benchmark.registerBenchmark("CLBG::Nbody") { Nbody() }
    Benchmark.registerBenchmark("CLBG::RegexDna") { RegexDna() }
    Benchmark.registerBenchmark("CLBG::Revcomp") { Revcomp() }
    Benchmark.registerBenchmark("CLBG::Spectralnorm") { Spectralnorm() }
    Benchmark.registerBenchmark("Base64::Encode") { Base64Encode() }
    Benchmark.registerBenchmark("Base64::Decode") { Base64Decode() }
    Benchmark.registerBenchmark("Json::Generate") { JsonGenerate() }
    Benchmark.registerBenchmark("Json::ParseDom") { JsonParseDom() }
    Benchmark.registerBenchmark("Json::ParseMapping") { JsonParseMapping() }
    Benchmark.registerBenchmark("Etc::Primes") { Primes() }
    Benchmark.registerBenchmark("Etc::Noise") { Noise() }
    Benchmark.registerBenchmark("Etc::TextRaytracer") { TextRaytracer() }
    Benchmark.registerBenchmark("Etc::NeuralNet") { NeuralNet() }
    Benchmark.registerBenchmark("Sort::Quick") { SortQuick() }
    Benchmark.registerBenchmark("Sort::Merge") { SortMerge() }
    Benchmark.registerBenchmark("Sort::Self") { SortSelf() }
    Benchmark.registerBenchmark("Graph::BFS") { GraphPathBFS() }
    Benchmark.registerBenchmark("Graph::DFS") { GraphPathDFS() }
    Benchmark.registerBenchmark("Graph::AStar") { GraphPathAStar() }
    Benchmark.registerBenchmark("Hash::SHA256") { BufferHashSHA256() }
    Benchmark.registerBenchmark("Hash::CRC32") { BufferHashCRC32() }
    Benchmark.registerBenchmark("Etc::CacheSimulation") { CacheSimulation() }
    Benchmark.registerBenchmark("Calculator::Ast") { CalculatorAst() }
    Benchmark.registerBenchmark("Calculator::Interpreter") { CalculatorInterpreter() }
    Benchmark.registerBenchmark("Etc::GameOfLife") { GameOfLife() }
    Benchmark.registerBenchmark("Maze::Generator") { MazeGenerator() }
    Benchmark.registerBenchmark("Maze::BFS") { MazeBFS() }
    Benchmark.registerBenchmark("Maze::AStar") { MazeAStar() }
    Benchmark.registerBenchmark("Compress::BWTEncode") { BWTEncode() }
    Benchmark.registerBenchmark("Compress::BWTDecode") { BWTDecode() }
    Benchmark.registerBenchmark("Compress::HuffEncode") { HuffEncode() }
    Benchmark.registerBenchmark("Compress::HuffDecode") { HuffDecode() }
    Benchmark.registerBenchmark("Compress::ArithEncode") { ArithEncode() }
    Benchmark.registerBenchmark("Compress::ArithDecode") { ArithDecode() }
    Benchmark.registerBenchmark("Compress::LZWEncode") { LZWEncode() }
    Benchmark.registerBenchmark("Compress::LZWDecode") { LZWDecode() }
    Benchmark.registerBenchmark("Distance::Jaro") { Distance.Jaro() }
    Benchmark.registerBenchmark("Distance::NGram") { Distance.NGram() }

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
