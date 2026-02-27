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
include("benchmarks/Sieve.jl")
include("benchmarks/TextRaytracer.jl")
include("benchmarks/NeuralNet.jl")
include("benchmarks/Sort.jl")
include("benchmarks/GraphPath.jl")
include("benchmarks/BufferHash.jl")
include("benchmarks/CacheSimulation.jl")
include("benchmarks/Calculator.jl")
include("benchmarks/GameOfLife.jl")
include("benchmarks/Maze.jl")
include("benchmarks/Compress.jl")
include("benchmarks/Distance.jl")

const ALL_BENCHMARKS = [
    ("CLBG::Pidigits", Pidigits),
    ("Binarytrees::Obj", BinarytreesObj),
    ("Binarytrees::Arena", BinarytreesArena),
    ("Brainfuck::Array", BrainfuckArray),
    ("Brainfuck::Recursion", BrainfuckRecursion),
    ("CLBG::Fannkuchredux", Fannkuchredux),
    ("CLBG::Fasta", Fasta),
    ("CLBG::Knuckeotide", Knuckeotide),
    ("CLBG::Mandelbrot", Mandelbrot),
    ("Matmul::Single", Matmul1T),
    ("Matmul::T4", Matmul4T),
    ("Matmul::T8", Matmul8T),
    ("Matmul::T16", Matmul16T),
    ("CLBG::Nbody", Nbody),
    ("CLBG::RegexDna", RegexDna),
    ("CLBG::Revcomp", Revcomp),
    ("CLBG::Spectralnorm", Spectralnorm),
    ("Base64::Encode", Base64Encode),
    ("Base64::Decode", Base64Decode),
    ("Json::Generate", JsonGenerate),
    ("Json::ParseDom", JsonParseDom),
    ("Json::ParseMapping", JsonParseMapping),
    ("Etc::Sieve", Sieve),
    ("Etc::TextRaytracer", TextRaytracer),
    ("Etc::NeuralNet", NeuralNet),
    ("Sort::Quick", SortQuick),
    ("Sort::Merge", SortMerge),
    ("Sort::Self", SortSelf),
    ("Graph::BFS", GraphPathBFS),
    ("Graph::DFS", GraphPathDFS),
    ("Graph::AStar", GraphPathAStar),
    ("Hash::SHA256", BufferHashSHA256),
    ("Hash::CRC32", BufferHashCRC32),
    ("Etc::CacheSimulation", CacheSimulation),
    ("Calculator::Ast", CalculatorAst),
    ("Calculator::Interpreter", CalculatorInterpreter),
    ("Etc::GameOfLife", GameOfLife),
    ("Maze::Generator", MazeGenerator),
    ("Maze::BFS", MazeBFS),
    ("Maze::AStar", MazeAStar),
    ("Compress::BWTEncode", BWTEncode),
    ("Compress::BWTDecode", BWTDecode),
    ("Compress::HuffEncode", HuffEncode),
    ("Compress::HuffDecode", HuffDecode),
    ("Compress::ArithEncode", ArithEncode),
    ("Compress::ArithDecode", ArithDecode),
    ("Compress::LZWEncode", LZWEncode),
    ("Compress::LZWDecode", LZWDecode),
    ("Distance::Jaro", Jaro),
    ("Distance::NGram", NGram),
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
        GC.gc()
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
