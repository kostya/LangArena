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
    let private createBenchmarkInfo<'T when 'T :> Benchmark and 'T : (new : unit -> 'T)> (prefix: string option) =
        let typeName = typeof<'T>.Name
        let name = 
            match prefix with
            | Some p -> $"{p}::{typeName}"
            | None -> typeName
        {
            Name = name
            Creator = fun () -> new 'T() :> Benchmark
        }

    let private benchmarkFactories = [
        createBenchmarkInfo<Pidigits> None
        createBenchmarkInfo<BinarytreesObj> None
        createBenchmarkInfo<BinarytreesArena> None
        createBenchmarkInfo<BrainfuckArray> None
        createBenchmarkInfo<BrainfuckRecursion> None
        createBenchmarkInfo<Fannkuchredux> None
        createBenchmarkInfo<Fasta> None
        createBenchmarkInfo<Knuckeotide> None
        createBenchmarkInfo<Mandelbrot> None
        createBenchmarkInfo<Matmul1T> None
        createBenchmarkInfo<Matmul4T> None
        createBenchmarkInfo<Matmul8T> None
        createBenchmarkInfo<Matmul16T> None
        createBenchmarkInfo<Nbody> None
        createBenchmarkInfo<RegexDna> None
        createBenchmarkInfo<Revcomp> None
        createBenchmarkInfo<Spectralnorm> None
        createBenchmarkInfo<Base64Encode> None
        createBenchmarkInfo<Base64Decode> None
        createBenchmarkInfo<JsonGenerate> None
        createBenchmarkInfo<JsonParseDom> None
        createBenchmarkInfo<JsonParseMapping> None
        createBenchmarkInfo<Primes> None
        createBenchmarkInfo<Noise> None
        createBenchmarkInfo<TextRaytracer> None
        createBenchmarkInfo<NeuralNet> None
        createBenchmarkInfo<SortQuick> None
        createBenchmarkInfo<SortMerge> None
        createBenchmarkInfo<SortSelf> None
        createBenchmarkInfo<GraphPathBFS> None
        createBenchmarkInfo<GraphPathDFS> None
        createBenchmarkInfo<GraphPathAStar> None
        createBenchmarkInfo<BufferHashSHA256> None
        createBenchmarkInfo<BufferHashCRC32> None
        createBenchmarkInfo<CacheSimulation> None
        createBenchmarkInfo<CalculatorAst> None
        createBenchmarkInfo<CalculatorInterpreter> None
        createBenchmarkInfo<GameOfLife> None
        createBenchmarkInfo<MazeGenerator> None
        createBenchmarkInfo<AStarPathfinder> None
        createBenchmarkInfo<BWTEncode> (Some "Compress")
        createBenchmarkInfo<BWTDecode> (Some "Compress")
        createBenchmarkInfo<HuffEncode> (Some "Compress")
        createBenchmarkInfo<HuffDecode> (Some "Compress")
        createBenchmarkInfo<ArithEncode> (Some "Compress")
        createBenchmarkInfo<ArithDecode> (Some "Compress")
        createBenchmarkInfo<LZWEncode> (Some "Compress")
        createBenchmarkInfo<LZWDecode> (Some "Compress")
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