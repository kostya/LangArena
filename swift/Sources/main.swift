import Foundation

main()

func main() {

  setenv("LANG", "en_US.UTF-8", 1)

  BenchmarkManager.register { Pidigits() }
  BenchmarkManager.register { BinarytreesObj() }
  BenchmarkManager.register { BinarytreesArena() }
  BenchmarkManager.register { BrainfuckArray() }
  BenchmarkManager.register { BrainfuckRecursion() }
  BenchmarkManager.register { Fannkuchredux() }
  BenchmarkManager.register { Fasta() }
  BenchmarkManager.register { Knuckeotide() }
  BenchmarkManager.register { Mandelbrot() }
  BenchmarkManager.register { Matmul1T() }
  BenchmarkManager.register { Matmul4T() }
  BenchmarkManager.register { Matmul8T() }
  BenchmarkManager.register { Matmul16T() }
  BenchmarkManager.register { Nbody() }
  BenchmarkManager.register { RegexDna() }
  BenchmarkManager.register { Revcomp() }
  BenchmarkManager.register { Spectralnorm() }
  BenchmarkManager.register { Base64Encode() }
  BenchmarkManager.register { Base64Decode() }
  BenchmarkManager.register { JsonGenerate() }
  BenchmarkManager.register { JsonParseDom() }
  BenchmarkManager.register { JsonParseMapping() }
  BenchmarkManager.register { Primes() }
  BenchmarkManager.register { Noise() }
  BenchmarkManager.register { TextRaytracer() }
  BenchmarkManager.register { NeuralNet() }
  BenchmarkManager.register { SortQuick() }
  BenchmarkManager.register { SortMerge() }
  BenchmarkManager.register { SortSelf() }
  BenchmarkManager.register { GraphPathBFS() }
  BenchmarkManager.register { GraphPathDFS() }
  BenchmarkManager.register { GraphPathAStar() }
  BenchmarkManager.register { BufferHashSHA256() }
  BenchmarkManager.register { BufferHashCRC32() }
  BenchmarkManager.register { CacheSimulation() }
  BenchmarkManager.register { CalculatorAst() }
  BenchmarkManager.register { CalculatorInterpreter() }
  BenchmarkManager.register { GameOfLife() }
  BenchmarkManager.register { MazeGenerator() }
  BenchmarkManager.register { AStarPathfinder() }
  BenchmarkManager.register { BWTHuffEncode() }
  BenchmarkManager.register { BWTHuffDecode() }

  let args = CommandLine.arguments.dropFirst()
  let configFile = args.first { $0.hasSuffix(".txt") || $0.hasSuffix(".js") }
  let singleBench = args.first { !$0.hasSuffix(".txt") && !$0.hasSuffix(".js") }

  do {
    try Helper.loadConfig(filename: configFile)

    if Helper.config.isEmpty {
      fputs("Warning: No test cases loaded from config file\n", stderr)
      fputs("Usage: swift run Benchmarks test.js BrainfuckHashMap\n", stderr)
      fputs("Or: swift run Benchmarks ../run.js\n", stderr)
      exit(1)
    }
  } catch {
    fputs("Error loading config file '\(configFile ?? "test.js")': \(error)\n", stderr)
    exit(1)
  }

  do {
    try "RECOMPILE_MARKER_0".write(
      toFile: "/tmp/recompile_marker",
      atomically: true,
      encoding: .utf8)
  } catch {

  }

  BenchmarkManager.run(singleBench: singleBench)
}
