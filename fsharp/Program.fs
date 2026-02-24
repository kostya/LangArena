open System
open Benchmarks
open System.Globalization
open System.Threading
open System.Collections.Generic
open System.Diagnostics
open System.IO
open System.Text.Json

type BenchmarkInfo = {
    Name: string
    Creator: unit -> Benchmark
}

module BenchmarkRunner =
    let private createBenchmarkInfo<'T when 'T :> Benchmark and 'T : (new : unit -> 'T)> (fullName: string) =
        {
            Name = fullName
            Creator = fun () -> new 'T() :> Benchmark
        }

    let private benchmarkFactories = [

        createBenchmarkInfo<Pidigits> "CLBG::Pidigits"
        createBenchmarkInfo<Fannkuchredux> "CLBG::Fannkuchredux"
        createBenchmarkInfo<Fasta> "CLBG::Fasta"
        createBenchmarkInfo<Knuckeotide> "CLBG::Knuckeotide"
        createBenchmarkInfo<Mandelbrot> "CLBG::Mandelbrot"
        createBenchmarkInfo<Nbody> "CLBG::Nbody"
        createBenchmarkInfo<RegexDna> "CLBG::RegexDna"
        createBenchmarkInfo<Revcomp> "CLBG::Revcomp"
        createBenchmarkInfo<Spectralnorm> "CLBG::Spectralnorm"

        createBenchmarkInfo<BinarytreesObj> "Binarytrees::Obj"
        createBenchmarkInfo<BinarytreesArena> "Binarytrees::Arena"

        createBenchmarkInfo<BrainfuckArray> "Brainfuck::Array"
        createBenchmarkInfo<BrainfuckRecursion> "Brainfuck::Recursion"

        createBenchmarkInfo<Matmul1T> "Matmul::T1"
        createBenchmarkInfo<Matmul4T> "Matmul::T4"
        createBenchmarkInfo<Matmul8T> "Matmul::T8"
        createBenchmarkInfo<Matmul16T> "Matmul::T16"

        createBenchmarkInfo<Base64Encode> "Base64::Encode"
        createBenchmarkInfo<Base64Decode> "Base64::Decode"

        createBenchmarkInfo<JsonGenerate> "Json::Generate"
        createBenchmarkInfo<JsonParseDom> "Json::ParseDom"
        createBenchmarkInfo<JsonParseMapping> "Json::ParseMapping"

        createBenchmarkInfo<Primes> "Etc::Primes"
        createBenchmarkInfo<Noise> "Etc::Noise"
        createBenchmarkInfo<TextRaytracer> "Etc::TextRaytracer"
        createBenchmarkInfo<NeuralNet> "Etc::NeuralNet"
        createBenchmarkInfo<CacheSimulation> "Etc::CacheSimulation"
        createBenchmarkInfo<GameOfLife> "Etc::GameOfLife"

        createBenchmarkInfo<SortQuick> "Sort::Quick"
        createBenchmarkInfo<SortMerge> "Sort::Merge"
        createBenchmarkInfo<SortSelf> "Sort::Self"

        createBenchmarkInfo<GraphPathBFS> "Graph::BFS"
        createBenchmarkInfo<GraphPathDFS> "Graph::DFS"
        createBenchmarkInfo<GraphPathAStar> "Graph::AStar"

        createBenchmarkInfo<BufferHashSHA256> "Hash::SHA256"
        createBenchmarkInfo<BufferHashCRC32> "Hash::CRC32"

        createBenchmarkInfo<CalculatorAst> "Calculator::Ast"
        createBenchmarkInfo<CalculatorInterpreter> "Calculator::Interpreter"

        createBenchmarkInfo<MazeGenerator> "Maze::Generator"
        createBenchmarkInfo<MazeBFS> "Maze::BFS"
        createBenchmarkInfo<MazeAStar> "Maze::AStar"

        createBenchmarkInfo<BWTEncode> "Compress::BWTEncode"
        createBenchmarkInfo<BWTDecode> "Compress::BWTDecode"
        createBenchmarkInfo<HuffEncode> "Compress::HuffEncode"
        createBenchmarkInfo<HuffDecode> "Compress::HuffDecode"
        createBenchmarkInfo<ArithEncode> "Compress::ArithEncode"
        createBenchmarkInfo<ArithDecode> "Compress::ArithDecode"
        createBenchmarkInfo<LZWEncode> "Compress::LZWEncode"
        createBenchmarkInfo<LZWDecode> "Compress::LZWDecode"
    ]

    let private runBenchmark (factory: BenchmarkInfo) (singleBench: string option) =
        let className = factory.Name

        match singleBench with
        | Some filter when not (className.ToLower().Contains(filter.ToLower())) ->
            None
        | _ ->
            let mutable benchConfig = JsonElement()
            if not (Helper.Config.TryGetProperty(className, &benchConfig)) then
                Console.WriteLine($"Skipping {className} - no config in test.js")
                None
            else
                Console.Write($"{className}: ")
                Helper.Reset()

                try

                    let benchmark = factory.Creator()

                    benchmark.Prepare()
                    benchmark.Warmup()
                    GC.Collect()

                    Helper.Reset()

                    let stopwatch = Stopwatch.StartNew()
                    benchmark.RunAll()
                    stopwatch.Stop()

                    let timeDelta = stopwatch.Elapsed.TotalSeconds
                    benchmark.TimeDelta <- timeDelta

                    GC.Collect()
                    Thread.Sleep(0)
                    GC.Collect()

                    let actual = benchmark.Checksum
                    let expected = uint32 benchmark.ExpectedChecksum

                    if actual = expected then
                        Console.Write("OK ")
                        Some (className, timeDelta, true)
                    else
                        Console.Write($"ERR[actual={actual}, expected={expected}] ")
                        Some (className, timeDelta, false)
                with
                | ex -> 
                    Console.WriteLine($"ERROR: {ex.Message}")
                    Some (className, 0.0, false)

    let All(singleBench: string option) =
        let now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        Console.WriteLine($"start: {now}")

        let results = Dictionary<string, double>()
        let mutable summaryTime = 0.0
        let mutable ok = 0
        let mutable fails = 0

        for factory in benchmarkFactories do
            match runBenchmark factory singleBench with
            | Some (className, timeDelta, success) ->
                if timeDelta > 0.0 then
                    results.[className] <- timeDelta
                    summaryTime <- summaryTime + timeDelta

                Console.WriteLine($"in {timeDelta:F3}s")
                if success then
                    ok <- ok + 1
                else
                    fails <- fails + 1
            | None -> ()

        try
            let jsonEntries = results |> Seq.map (fun kv -> $"\"{kv.Key}\":{kv.Value}")
            let json = "{" + String.Join(",", jsonEntries) + "}"
            File.WriteAllText("/tmp/results.js", json)
        with
        | ex -> Console.WriteLine($"Error saving results: {ex.Message}")

        Console.WriteLine("Summary: {0:F4}s, {1}, {2}, {3}", summaryTime, ok + fails, ok, fails)

        File.WriteAllText("/tmp/recompile_marker", "RECOMPILE_MARKER_0")

        if fails > 0 || ok = 0 then
            Environment.Exit(1)

[<EntryPoint>]
let main argv =
    Thread.CurrentThread.CurrentCulture <- CultureInfo.InvariantCulture

    let configFile = 
        if argv.Length > 0 then argv.[0]
        else "test.js"

    Helper.LoadConfig(configFile)

    let singleBench = 
        if argv.Length > 1 then Some argv.[1]
        else None

    BenchmarkRunner.All(singleBench)

    0