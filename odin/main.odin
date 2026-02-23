package main

import "core:fmt"
import "core:os"
import "core:time"
import "benchmark"

main :: proc() {
    defer benchmark.helper_cleanup()

    benchmark.helper_init()

    benchmark.register_benchmark_factory("Pidigits", benchmark.create_pidigits)
    benchmark.register_benchmark_factory("BinarytreesObj", benchmark.create_binarytrees_obj)
    benchmark.register_benchmark_factory("BinarytreesArena", benchmark.create_binarytrees_arena)
    benchmark.register_benchmark_factory("BrainfuckArray", benchmark.create_brainfuckarray)
    benchmark.register_benchmark_factory("BrainfuckRecursion", benchmark.create_brainfuckrecursion)
    benchmark.register_benchmark_factory("Fannkuchredux", benchmark.create_fannkuchredux)
    benchmark.register_benchmark_factory("Fasta", benchmark.create_fasta)
    benchmark.register_benchmark_factory("Knuckeotide", benchmark.create_knuckeotide)
    benchmark.register_benchmark_factory("Mandelbrot", benchmark.create_mandelbrot)
    benchmark.register_benchmark_factory("Matmul1T", benchmark.create_matmul1t)
    benchmark.register_benchmark_factory("Matmul4T", benchmark.create_matmul4t)
    benchmark.register_benchmark_factory("Matmul8T", benchmark.create_matmul8t)
    benchmark.register_benchmark_factory("Matmul16T", benchmark.create_matmul16t)
    benchmark.register_benchmark_factory("Nbody", benchmark.create_nbody)
    benchmark.register_benchmark_factory("RegexDna", benchmark.create_regexdna)
    benchmark.register_benchmark_factory("Revcomp", benchmark.create_revcomp)
    benchmark.register_benchmark_factory("Spectralnorm", benchmark.create_spectralnorm)
    benchmark.register_benchmark_factory("Base64Encode", benchmark.create_base64encode)
    benchmark.register_benchmark_factory("Base64Decode", benchmark.create_base64decode)
    benchmark.register_benchmark_factory("JsonGenerate", benchmark.create_jsongenerate)
    benchmark.register_benchmark_factory("JsonParseDom", benchmark.create_jsonparsedom)
    benchmark.register_benchmark_factory("JsonParseMapping", benchmark.create_jsonparsemapping)
    benchmark.register_benchmark_factory("Primes", benchmark.create_primes)
    benchmark.register_benchmark_factory("Noise", benchmark.create_noise)
    benchmark.register_benchmark_factory("TextRaytracer", benchmark.create_textraytracer)
    benchmark.register_benchmark_factory("NeuralNet", benchmark.create_neuralnet)
    benchmark.register_benchmark_factory("SortQuick", benchmark.create_sortquick)
    benchmark.register_benchmark_factory("SortMerge", benchmark.create_sortmerge)
    benchmark.register_benchmark_factory("SortSelf", benchmark.create_sortself)
    benchmark.register_benchmark_factory("GraphPathBFS", benchmark.create_graphbfs)
    benchmark.register_benchmark_factory("GraphPathDFS", benchmark.create_graphdfs)
    benchmark.register_benchmark_factory("GraphPathAStar", benchmark.create_graphastar)
    benchmark.register_benchmark_factory("BufferHashSHA256", benchmark.create_buffhashsha256)
    benchmark.register_benchmark_factory("BufferHashCRC32", benchmark.create_buffhashcrc32)
    benchmark.register_benchmark_factory("CacheSimulation", benchmark.create_cachesimulation)
    benchmark.register_benchmark_factory("CalculatorAst", benchmark.create_calculatorast)
    benchmark.register_benchmark_factory("CalculatorInterpreter", benchmark.create_calculatorinterpreter)
    benchmark.register_benchmark_factory("GameOfLife", benchmark.create_gameoflife)
    benchmark.register_benchmark_factory("MazeGenerator", benchmark.create_mazegenerator)
    benchmark.register_benchmark_factory("AStarPathfinder", benchmark.create_astarpathfinder)
    benchmark.register_benchmark_factory("Compress::BWTEncode", benchmark.create_bwtencode)
    benchmark.register_benchmark_factory("Compress::BWTDecode", benchmark.create_bwtdecode)
    benchmark.register_benchmark_factory("Compress::HuffEncode", benchmark.create_huffencode)
    benchmark.register_benchmark_factory("Compress::HuffDecode", benchmark.create_huffdecode)
    benchmark.register_benchmark_factory("Compress::ArithEncode", benchmark.create_arithencode)
    benchmark.register_benchmark_factory("Compress::ArithDecode", benchmark.create_arithdecode)
    benchmark.register_benchmark_factory("Compress::LZWEncode", benchmark.create_lzwencode)
    benchmark.register_benchmark_factory("Compress::LZWDecode", benchmark.create_lzwdecode)

    config_file := "../test.json"
    if len(os.args) > 1 {
        config_file = os.args[1]
    }

    if !benchmark.load_config(config_file) {
        fmt.eprintln("Failed to load config")
        os.exit(1)
    }

    now := time.now()
    nanoseconds := time.to_unix_nanoseconds(now)
    milliseconds := f64(nanoseconds) / 1_000_000.0
    fmt.printf("start: %.0f\n", milliseconds)

    single_bench := ""
    if len(os.args) > 2 {
        single_bench = os.args[2]
    }

    benchmark.run_all_benchmarks(single_bench)

    data := "RECOMPILE_MARKER_0"
    os.write_entire_file("/tmp/recompile_marker", transmute([]u8)data)
}