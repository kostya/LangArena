import Foundation

// Точка входа
main()

func main() {
    // Устанавливаем локаль для консистентности
    setenv("LANG", "en_US.UTF-8", 1)

    BenchmarkManager.register { Pidigits() }
    BenchmarkManager.register { Binarytrees() }
    BenchmarkManager.register { BrainfuckHashMap() }
    BenchmarkManager.register { BrainfuckRecursion() }
    BenchmarkManager.register { Fannkuchredux() }
    BenchmarkManager.register { Fasta() }
    BenchmarkManager.register { Knuckeotide() }
    BenchmarkManager.register { Mandelbrot() }
    BenchmarkManager.register { Matmul() }
    BenchmarkManager.register { Matmul4T() }
    BenchmarkManager.register { Matmul8T() }
    BenchmarkManager.register { Matmul16T() }
    BenchmarkManager.register { Nbody() }
    BenchmarkManager.register { RegexDna() }
    BenchmarkManager.register { Revcomp() }
    BenchmarkManager.register { Spectralnorm() }
    BenchmarkManager.register { Base64Encode() }
    BenchmarkManager.register { Base64Decode() }
    BenchmarkManager.register { Primes() }
    BenchmarkManager.register { JsonGenerate() }
    BenchmarkManager.register { JsonParseDom() }
    BenchmarkManager.register { JsonParseMapping() }
    BenchmarkManager.register { Noise() }
    BenchmarkManager.register { TextRaytracer() }
    BenchmarkManager.register { NeuralNet() }
    BenchmarkManager.register { SortQuick() }
    BenchmarkManager.register { SortMerge() }
    BenchmarkManager.register { SortSelf() }
    BenchmarkManager.register { GraphPathBFS() }
    BenchmarkManager.register { GraphPathDFS() }
    BenchmarkManager.register { GraphPathDijkstra() }
    BenchmarkManager.register { BufferHashSHA256() }
    BenchmarkManager.register { BufferHashCRC32() }
    BenchmarkManager.register { CacheSimulation() }
    BenchmarkManager.register { CalculatorAst() }
    BenchmarkManager.register { CalculatorInterpreter() }
    BenchmarkManager.register { GameOfLife() }
    BenchmarkManager.register { MazeGenerator() }
    BenchmarkManager.register { AStarPathfinder() }
    BenchmarkManager.register { Compression() }
        
    // Обработка аргументов командной строки
    let args = CommandLine.arguments.dropFirst()
    let configFile = args.first { $0.hasSuffix(".txt") }
    let singleBench = args.first { !$0.hasSuffix(".txt") }
    
    do {
        try Helper.loadConfig(filename: configFile)
        
        if Helper.input.isEmpty {
            fputs("Warning: No test cases loaded from config file\n", stderr)
            fputs("Usage: swift run Benchmarks test.txt BrainfuckHashMap\n", stderr)
            fputs("Or: swift run Benchmarks ../run.txt\n", stderr)
            exit(1)
        }
    } catch {
        fputs("Error loading config file '\(configFile ?? "test.txt")': \(error)\n", stderr)
        exit(1)
    }


    do {
        try "RECOMPILE_MARKER_0".write(toFile: "/tmp/recompile_marker", 
                            atomically: true, 
                            encoding: .utf8)
    } catch {
        // игнорируем ошибку
    }
    
    BenchmarkManager.run(singleBench: singleBench)
}