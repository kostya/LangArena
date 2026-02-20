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

    let private createBenchmarkInfo<'T when 'T :> Benchmark and 'T : (new : unit -> 'T)> () =
        {
            Name = typeof<'T>.Name
            Creator = fun () -> new 'T() :> Benchmark
        }

    let private benchmarkFactories = [
        createBenchmarkInfo<Pidigits> ()
        createBenchmarkInfo<BinarytreesObj> ()
        createBenchmarkInfo<BinarytreesArena> ()
        createBenchmarkInfo<BrainfuckArray> ()
        createBenchmarkInfo<BrainfuckRecursion> ()
        createBenchmarkInfo<Fannkuchredux> ()
        createBenchmarkInfo<Fasta> ()
        createBenchmarkInfo<Knuckeotide> ()
        createBenchmarkInfo<Mandelbrot> ()
        createBenchmarkInfo<Matmul1T> ()
        createBenchmarkInfo<Matmul4T> ()
        createBenchmarkInfo<Matmul8T> ()
        createBenchmarkInfo<Matmul16T> ()
        createBenchmarkInfo<Nbody> ()
        createBenchmarkInfo<RegexDna> ()
        createBenchmarkInfo<Revcomp> ()
        createBenchmarkInfo<Spectralnorm> ()
        createBenchmarkInfo<Base64Encode> ()
        createBenchmarkInfo<Base64Decode> ()
        createBenchmarkInfo<JsonGenerate> ()
        createBenchmarkInfo<JsonParseDom> ()
        createBenchmarkInfo<JsonParseMapping> ()
        createBenchmarkInfo<Primes> ()
        createBenchmarkInfo<Noise> ()
        createBenchmarkInfo<TextRaytracer> ()
        createBenchmarkInfo<NeuralNet> ()
        createBenchmarkInfo<SortQuick> ()
        createBenchmarkInfo<SortMerge> ()
        createBenchmarkInfo<SortSelf> ()
        createBenchmarkInfo<GraphPathBFS> ()
        createBenchmarkInfo<GraphPathDFS> ()
        createBenchmarkInfo<GraphPathAStar> ()
        createBenchmarkInfo<BufferHashSHA256> ()
        createBenchmarkInfo<BufferHashCRC32> ()
        createBenchmarkInfo<CacheSimulation> ()
        createBenchmarkInfo<CalculatorAst> ()
        createBenchmarkInfo<CalculatorInterpreter> ()
        createBenchmarkInfo<GameOfLife> ()
        createBenchmarkInfo<MazeGenerator> ()
        createBenchmarkInfo<AStarPathfinder> ()
        createBenchmarkInfo<BWTHuffEncode> ()
        createBenchmarkInfo<BWTHuffDecode> ()
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

                if success then
                    ok <- ok + 1
                    Console.WriteLine($"in {timeDelta:F3}s")
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