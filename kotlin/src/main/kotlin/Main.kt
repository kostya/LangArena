import benchmarks.*
import kotlin.system.exitProcess
import java.util.Locale
import java.io.File

fun main(args: Array<String>) {
    Locale.setDefault(Locale.US)

    Benchmark.registerBenchmark { Pidigits() }
    Benchmark.registerBenchmark { Binarytrees() }
    Benchmark.registerBenchmark { BrainfuckHashMap() }
    Benchmark.registerBenchmark { BrainfuckRecursion() }            
    Benchmark.registerBenchmark { Fannkuchredux() }
    Benchmark.registerBenchmark { Fasta() }
    Benchmark.registerBenchmark { Knuckeotide() }
    Benchmark.registerBenchmark { Mandelbrot() }
    Benchmark.registerBenchmark { Matmul() }
    Benchmark.registerBenchmark { Matmul4T() }
    Benchmark.registerBenchmark { Matmul8T() }
    Benchmark.registerBenchmark { Matmul16T() }
    Benchmark.registerBenchmark { Nbody() }
    Benchmark.registerBenchmark { RegexDna() }
    Benchmark.registerBenchmark { Revcomp() }
    Benchmark.registerBenchmark { Spectralnorm() }
    Benchmark.registerBenchmark { Base64Encode() }
    Benchmark.registerBenchmark { Base64Decode() }    
    Benchmark.registerBenchmark { JsonGenerate() }
    Benchmark.registerBenchmark { JsonParseDom() }
    Benchmark.registerBenchmark { JsonParseMapping() }    
    Benchmark.registerBenchmark { Primes() }
    Benchmark.registerBenchmark { Noise() }
    Benchmark.registerBenchmark { TextRaytracer() }
    Benchmark.registerBenchmark { NeuralNet() }
    Benchmark.registerBenchmark { SortQuick() }
    Benchmark.registerBenchmark { SortMerge() }
    Benchmark.registerBenchmark { SortSelf() }
    Benchmark.registerBenchmark { GraphPathBFS() }
    Benchmark.registerBenchmark { GraphPathDFS() }
    Benchmark.registerBenchmark { GraphPathDijkstra() }
    Benchmark.registerBenchmark { BufferHashSHA256() }
    Benchmark.registerBenchmark { BufferHashCRC32() }    
    Benchmark.registerBenchmark { CacheSimulation() }        
    Benchmark.registerBenchmark { CalculatorAst() }    
    Benchmark.registerBenchmark { CalculatorInterpreter() }    
    Benchmark.registerBenchmark { GameOfLife() }        
    Benchmark.registerBenchmark { MazeGenerator() }    
    Benchmark.registerBenchmark { AStarPathfinder() }    
    Benchmark.registerBenchmark { Compression() }  
    

    // Обработка аргументов: первый аргумент - файл конфигурации, второй - имя бенчмарка
    val configFile = when {
        args.isNotEmpty() && args[0].endsWith(".txt") -> args[0]
        args.size > 1 && args[1].endsWith(".txt") -> args[1]
        else -> null
    }
    
    val singleBench = args.firstOrNull { !it.endsWith(".txt") }
    
    try {
        Helper.loadConfig(configFile)
        
        if (Helper.INPUT.isEmpty()) {
            System.err.println("Warning: No test cases loaded from config file")
            System.err.println("Usage: ./gradlew run --args=\"test.txt BrainfuckRecursion\"")
            System.err.println("Or: ./gradlew run --args=\"../run.txt\"")
            exitProcess(1)
        }
    } catch (e: Exception) {
        System.err.println("Error loading config file '${configFile ?: "test.txt"}': ${e.message}")
        e.printStackTrace()
        exitProcess(1)
    }

    File("/tmp/recompile_marker").writeText("RECOMPILE_MARKER_0")
    
    Benchmark.run(singleBench)
}