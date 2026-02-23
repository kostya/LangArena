import Foundation

main()

func main() {

  setenv("LANG", "en_US.UTF-8", 1)

  BenchmarkManager.register("Pidigits") { Pidigits() }
  BenchmarkManager.register("BinarytreesObj") { BinarytreesObj() }
  BenchmarkManager.register("BinarytreesArena") { BinarytreesArena() }
  BenchmarkManager.register("BrainfuckArray") { BrainfuckArray() }
  BenchmarkManager.register("BrainfuckRecursion") { BrainfuckRecursion() }
  BenchmarkManager.register("Fannkuchredux") { Fannkuchredux() }
  BenchmarkManager.register("Fasta") { Fasta() }
  BenchmarkManager.register("Knuckeotide") { Knuckeotide() }
  BenchmarkManager.register("Mandelbrot") { Mandelbrot() }
  BenchmarkManager.register("Matmul1T") { Matmul1T() }
  BenchmarkManager.register("Matmul4T") { Matmul4T() }
  BenchmarkManager.register("Matmul8T") { Matmul8T() }
  BenchmarkManager.register("Matmul16T") { Matmul16T() }
  BenchmarkManager.register("Nbody") { Nbody() }
  BenchmarkManager.register("RegexDna") { RegexDna() }
  BenchmarkManager.register("Revcomp") { Revcomp() }
  BenchmarkManager.register("Spectralnorm") { Spectralnorm() }
  BenchmarkManager.register("Base64Encode") { Base64Encode() }
  BenchmarkManager.register("Base64Decode") { Base64Decode() }
  BenchmarkManager.register("JsonGenerate") { JsonGenerate() }
  BenchmarkManager.register("JsonParseDom") { JsonParseDom() }
  BenchmarkManager.register("JsonParseMapping") { JsonParseMapping() }
  BenchmarkManager.register("Primes") { Primes() }
  BenchmarkManager.register("Noise") { Noise() }
  BenchmarkManager.register("TextRaytracer") { TextRaytracer() }
  BenchmarkManager.register("NeuralNet") { NeuralNet() }
  BenchmarkManager.register("SortQuick") { SortQuick() }
  BenchmarkManager.register("SortMerge") { SortMerge() }
  BenchmarkManager.register("SortSelf") { SortSelf() }
  BenchmarkManager.register("GraphPathBFS") { GraphPathBFS() }
  BenchmarkManager.register("GraphPathDFS") { GraphPathDFS() }
  BenchmarkManager.register("GraphPathAStar") { GraphPathAStar() }
  BenchmarkManager.register("BufferHashSHA256") { BufferHashSHA256() }
  BenchmarkManager.register("BufferHashCRC32") { BufferHashCRC32() }
  BenchmarkManager.register("CacheSimulation") { CacheSimulation() }
  BenchmarkManager.register("CalculatorAst") { CalculatorAst() }
  BenchmarkManager.register("CalculatorInterpreter") { CalculatorInterpreter() }
  BenchmarkManager.register("GameOfLife") { GameOfLife() }
  BenchmarkManager.register("MazeGenerator") { MazeGenerator() }
  BenchmarkManager.register("AStarPathfinder") { AStarPathfinder() }
  BenchmarkManager.register("Compress::BWTEncode") { BWTEncode() }
  BenchmarkManager.register("Compress::BWTDecode") { BWTDecode() }
  BenchmarkManager.register("Compress::HuffEncode") { HuffEncode() }
  BenchmarkManager.register("Compress::HuffDecode") { HuffDecode() }
  BenchmarkManager.register("Compress::ArithEncode") { ArithEncode() }
  BenchmarkManager.register("Compress::ArithDecode") { ArithDecode() }
  BenchmarkManager.register("Compress::LZWEncode") { LZWEncode() }
  BenchmarkManager.register("Compress::LZWDecode") { LZWDecode() }

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
