module BenchmarkFramework

using JSON3
using Printf
using Random
using Statistics

export Benchmark, AbstractBenchmark, run_all_benchmarks
export Helper, config_i64, config_s

include("Helper.jl")
include("Benchmark.jl")

include("benchmarks/Pidigits.jl")
include("benchmarks/Binarytrees.jl")
include("benchmarks/BrainfuckArray.jl")
include("benchmarks/BrainfuckRecursion.jl")
include("benchmarks/Fannkuchredux.jl")
include("benchmarks/Fasta.jl")
include("benchmarks/Knuckeotide.jl")
include("benchmarks/Mandelbrot.jl")
include("benchmarks/Matmul.jl")
include("benchmarks/Nbody.jl")
include("benchmarks/RegexDna.jl")
include("benchmarks/Revcomp.jl")
include("benchmarks/Spectralnorm.jl")
include("benchmarks/Base64Encode.jl")
include("benchmarks/Base64Decode.jl")
include("benchmarks/Json.jl")
include("benchmarks/Primes.jl")
include("benchmarks/Noise.jl")
include("benchmarks/TextRaytracer.jl")
include("benchmarks/NeuralNet.jl")
include("benchmarks/Sort.jl")
include("benchmarks/GraphPath.jl")
include("benchmarks/BufferHash.jl")
include("benchmarks/CacheSimulation.jl")
include("benchmarks/Calculator.jl")
include("benchmarks/GameOfLife.jl")
include("benchmarks/MazeGenerator.jl")
include("benchmarks/AStarPathfinder.jl")
include("benchmarks/BWTHuff.jl")

const ALL_BENCHMARKS = [
    ("Pidigits", Pidigits),
    ("Binarytrees", Binarytrees),
    ("BrainfuckArray", BrainfuckArray),
    ("BrainfuckRecursion", BrainfuckRecursion),
    ("Fannkuchredux", Fannkuchredux),
    ("Fasta", Fasta),
    ("Knuckeotide", Knuckeotide),
    ("Mandelbrot", Mandelbrot),
    ("Matmul1T", Matmul1T),
    ("Matmul4T", Matmul4T),
    ("Matmul8T", Matmul8T),
    ("Matmul16T", Matmul16T),
    ("Nbody", Nbody),
    ("RegexDna", RegexDna),
    ("Revcomp", Revcomp),
    ("Spectralnorm", Spectralnorm),
    ("Base64Encode", Base64Encode),
    ("Base64Decode", Base64Decode),
    ("JsonGenerate", JsonGenerate),
    ("JsonParseDom", JsonParseDom),
    ("JsonParseMapping", JsonParseMapping),
    ("Primes", Primes),
    ("Noise", Noise),
    ("TextRaytracer", TextRaytracer),
    ("NeuralNet", NeuralNet),
    ("SortQuick", SortQuick),
    ("SortMerge", SortMerge),
    ("SortSelf", SortSelf),
    ("GraphPathBFS", GraphPathBFS),
    ("GraphPathDFS", GraphPathDFS),
    ("GraphPathAStar", GraphPathAStar),
    ("BufferHashSHA256", BufferHashSHA256),
    ("BufferHashCRC32", BufferHashCRC32),
    ("CacheSimulation", CacheSimulation),
    ("CalculatorAst", CalculatorAst),
    ("CalculatorInterpreter", CalculatorInterpreter),
    ("GameOfLife", GameOfLife),
    ("MazeGenerator", MazeGenerator),
    ("AStarPathfinder", AStarPathfinder),
    ("BWTHuffEncode", BWTHuffEncode),
    ("BWTHuffDecode", BWTHuffDecode),
]

function run_all_benchmarks(single_bench::String = "")
    results = Dict{String,Float64}()
    summary_time = 0.0
    ok = 0
    fails = 0

    for (name, BenchmarkType) in ALL_BENCHMARKS
        if !isempty(single_bench) && !occursin(lowercase(single_bench), lowercase(name))
            continue
        end

        print("$name: ")
        flush(stdout)

        bench = BenchmarkType()
        Helper.reset()
        prepare(bench)

        warmup(bench)
        Helper.reset()

        start_time = time()
        run_all(bench)
        end_time = time()

        duration = end_time - start_time
        results[name] = duration

        if checksum(bench) == expected_checksum(bench)
            print("OK ")
            ok += 1
        else
            print("ERR[actual=$(checksum(bench)), expected=$(expected_checksum(bench))] ")
            fails += 1
        end

        println("in $(@sprintf("%.3f", duration))s")

        summary_time += duration
        GC.gc()
        sleep(0.001)
        GC.gc()
    end

    if !isempty(results)
        open("/tmp/results.js", "w") do f
            write(f, "{")
            first = true

            for (name, BenchmarkType) in ALL_BENCHMARKS
                if haskey(results, name)
                    if !first
                        write(f, ",")
                    end
                    write(f, "\"$name\":$(results[name])")
                    first = false
                end
            end
            write(f, "}")
        end
    end

    if ok + fails > 0
        println("Summary: $(@sprintf("%.4f", summary_time))s, $(ok+fails), $ok, $fails")
    end

    if fails > 0
        exit(1)
    end
end

function main()
    println("start: $(round(Int, time() * 1000))")

    if length(ARGS) > 0
        Helper.load_config(ARGS[1])
    else
        Helper.load_config("../test.js")
    end

    if length(ARGS) > 1
        run_all_benchmarks(ARGS[2])
    else
        run_all_benchmarks()
    end

    open("/tmp/recompile_marker", "w") do f
        write(f, "RECOMPILE_MARKER_0")
    end
end

end
