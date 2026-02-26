import Foundation

main()

func main() {

  setenv("LANG", "en_US.UTF-8", 1)

  BenchmarkManager.register("CLBG::Pidigits") { Pidigits() }
  BenchmarkManager.register("Binarytrees::Obj") { BinarytreesObj() }
  BenchmarkManager.register("Binarytrees::Arena") { BinarytreesArena() }
  BenchmarkManager.register("Brainfuck::Array") { BrainfuckArray() }
  BenchmarkManager.register("Brainfuck::Recursion") { BrainfuckRecursion() }
  BenchmarkManager.register("CLBG::Fannkuchredux") { Fannkuchredux() }
  BenchmarkManager.register("CLBG::Fasta") { Fasta() }
  BenchmarkManager.register("CLBG::Knuckeotide") { Knuckeotide() }
  BenchmarkManager.register("CLBG::Mandelbrot") { Mandelbrot() }
  BenchmarkManager.register("Matmul::Single") { Matmul1T() }
  BenchmarkManager.register("Matmul::T4") { Matmul4T() }
  BenchmarkManager.register("Matmul::T8") { Matmul8T() }
  BenchmarkManager.register("Matmul::T16") { Matmul16T() }
  BenchmarkManager.register("CLBG::Nbody") { Nbody() }
  BenchmarkManager.register("CLBG::RegexDna") { RegexDna() }
  BenchmarkManager.register("CLBG::Revcomp") { Revcomp() }
  BenchmarkManager.register("CLBG::Spectralnorm") { Spectralnorm() }
  BenchmarkManager.register("Base64::Encode") { Base64Encode() }
  BenchmarkManager.register("Base64::Decode") { Base64Decode() }
  BenchmarkManager.register("Json::Generate") { JsonGenerate() }
  BenchmarkManager.register("Json::ParseDom") { JsonParseDom() }
  BenchmarkManager.register("Json::ParseMapping") { JsonParseMapping() }
  BenchmarkManager.register("Etc::Primes") { Primes() }
  BenchmarkManager.register("Etc::Noise") { Noise() }
  BenchmarkManager.register("Etc::TextRaytracer") { TextRaytracer() }
  BenchmarkManager.register("Etc::NeuralNet") { NeuralNet() }
  BenchmarkManager.register("Sort::Quick") { SortQuick() }
  BenchmarkManager.register("Sort::Merge") { SortMerge() }
  BenchmarkManager.register("Sort::Self") { SortSelf() }
  BenchmarkManager.register("Graph::BFS") { GraphPathBFS() }
  BenchmarkManager.register("Graph::DFS") { GraphPathDFS() }
  BenchmarkManager.register("Graph::AStar") { GraphPathAStar() }
  BenchmarkManager.register("Hash::SHA256") { BufferHashSHA256() }
  BenchmarkManager.register("Hash::CRC32") { BufferHashCRC32() }
  BenchmarkManager.register("Etc::CacheSimulation") { CacheSimulation() }
  BenchmarkManager.register("Calculator::Ast") { CalculatorAst() }
  BenchmarkManager.register("Calculator::Interpreter") { CalculatorInterpreter() }
  BenchmarkManager.register("Etc::GameOfLife") { GameOfLife() }
  BenchmarkManager.register("Maze::Generator") { MazeGenerator() }
  BenchmarkManager.register("Maze::BFS") { MazeBFS() }
  BenchmarkManager.register("Maze::AStar") { MazeAStar() }
  BenchmarkManager.register("Compress::BWTEncode") { BWTEncode() }
  BenchmarkManager.register("Compress::BWTDecode") { BWTDecode() }
  BenchmarkManager.register("Compress::HuffEncode") { HuffEncode() }
  BenchmarkManager.register("Compress::HuffDecode") { HuffDecode() }
  BenchmarkManager.register("Compress::ArithEncode") { ArithEncode() }
  BenchmarkManager.register("Compress::ArithDecode") { ArithDecode() }
  BenchmarkManager.register("Compress::LZWEncode") { LZWEncode() }
  BenchmarkManager.register("Compress::LZWDecode") { LZWDecode() }
  BenchmarkManager.register("Distance::Jaro") { Jaro() }
  BenchmarkManager.register("Distance::NGram") { NGram() }

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
