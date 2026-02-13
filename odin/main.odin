package main

import "core:fmt"
import "core:os"
import "core:time"
import "benchmark"

main :: proc() {
    defer benchmark.helper_cleanup()

    benchmark.helper_init()

    benchmark.register_benchmark_factory(benchmark.create_pidigits)
    benchmark.register_benchmark_factory(benchmark.create_binarytrees)
    benchmark.register_benchmark_factory(benchmark.create_brainfuckarray)
    benchmark.register_benchmark_factory(benchmark.create_brainfuckrecursion)
    benchmark.register_benchmark_factory(benchmark.create_fannkuchredux)
    benchmark.register_benchmark_factory(benchmark.create_fasta)
    benchmark.register_benchmark_factory(benchmark.create_knuckeotide)
    benchmark.register_benchmark_factory(benchmark.create_mandelbrot)
    benchmark.register_benchmark_factory(benchmark.create_matmul1t)
    benchmark.register_benchmark_factory(benchmark.create_matmul4t)
    benchmark.register_benchmark_factory(benchmark.create_matmul8t)
    benchmark.register_benchmark_factory(benchmark.create_matmul16t)
    benchmark.register_benchmark_factory(benchmark.create_nbody)
    benchmark.register_benchmark_factory(benchmark.create_regexdna)
    benchmark.register_benchmark_factory(benchmark.create_revcomp)
    benchmark.register_benchmark_factory(benchmark.create_spectralnorm)
    benchmark.register_benchmark_factory(benchmark.create_base64encode)
    benchmark.register_benchmark_factory(benchmark.create_base64decode)
    benchmark.register_benchmark_factory(benchmark.create_jsongenerate)
    benchmark.register_benchmark_factory(benchmark.create_jsonparsedom)
    benchmark.register_benchmark_factory(benchmark.create_jsonparsemapping)
    benchmark.register_benchmark_factory(benchmark.create_primes)
    benchmark.register_benchmark_factory(benchmark.create_noise)
    benchmark.register_benchmark_factory(benchmark.create_textraytracer)
    benchmark.register_benchmark_factory(benchmark.create_neuralnet)
    benchmark.register_benchmark_factory(benchmark.create_sortquick)
    benchmark.register_benchmark_factory(benchmark.create_sortmerge)
    benchmark.register_benchmark_factory(benchmark.create_sortself)
    benchmark.register_benchmark_factory(benchmark.create_graphbfs)
    benchmark.register_benchmark_factory(benchmark.create_graphdfs)
    benchmark.register_benchmark_factory(benchmark.create_graphdijkstra)
    benchmark.register_benchmark_factory(benchmark.create_buffhashsha256)
    benchmark.register_benchmark_factory(benchmark.create_buffhashcrc32)
    benchmark.register_benchmark_factory(benchmark.create_cachesimulation)
    benchmark.register_benchmark_factory(benchmark.create_calculatorast)
    benchmark.register_benchmark_factory(benchmark.create_calculatorinterpreter)
    benchmark.register_benchmark_factory(benchmark.create_gameoflife)
    benchmark.register_benchmark_factory(benchmark.create_mazegenerator)
    benchmark.register_benchmark_factory(benchmark.create_astarpathfinder)
    benchmark.register_benchmark_factory(benchmark.create_bwthuffencode)
    benchmark.register_benchmark_factory(benchmark.create_bwthuffdecode)

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