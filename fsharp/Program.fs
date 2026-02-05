open System
open Benchmarks
open System.Globalization
open System.Threading
open System.Collections.Generic
open System.Diagnostics
open System.IO
open System.Text.Json

module BenchmarkRunner =
    let All(singleBench: string option) =
        let singleBench = match singleBench with Some s -> s | None -> null

        let now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        Console.WriteLine($"start: {now}")

        let results = Dictionary<string, double>()
        let mutable summaryTime = 0.0
        let mutable ok = 0
        let mutable fails = 0

        let benchmarks = [
            Pidigits() :> Benchmark
            Binarytrees() :> Benchmark
            BrainfuckArray() :> Benchmark
            BrainfuckRecursion() :> Benchmark
            Fannkuchredux() :> Benchmark
            Fasta() :> Benchmark
            Knuckeotide() :> Benchmark
            Mandelbrot() :> Benchmark
            Matmul1T() :> Benchmark
            Matmul4T() :> Benchmark
            Matmul8T() :> Benchmark
            Matmul16T() :> Benchmark
            Nbody() :> Benchmark
            RegexDna() :> Benchmark
            Revcomp() :> Benchmark
            Spectralnorm() :> Benchmark
            Base64Encode() :> Benchmark
            Base64Decode() :> Benchmark
            JsonGenerate() :> Benchmark
            JsonParseDom() :> Benchmark
            JsonParseMapping() :> Benchmark
            Primes() :> Benchmark
            Noise() :> Benchmark
            TextRaytracer() :> Benchmark
            NeuralNet() :> Benchmark
            SortQuick() :> Benchmark
            SortMerge() :> Benchmark
            SortSelf() :> Benchmark
            GraphPathBFS() :> Benchmark
            GraphPathDFS() :> Benchmark
            GraphPathDijkstra() :> Benchmark
            BufferHashSHA256() :> Benchmark
            BufferHashCRC32() :> Benchmark
            CacheSimulation() :> Benchmark
            CalculatorAst() :> Benchmark
            CalculatorInterpreter() :> Benchmark
            GameOfLife() :> Benchmark
            MazeGenerator() :> Benchmark
            AStarPathfinder() :> Benchmark
            BWTHuffEncode() :> Benchmark
            BWTHuffDecode() :> Benchmark
        ]

        for benchmark in benchmarks do
            let className = benchmark.Name

            if not (String.IsNullOrEmpty singleBench) && 
               not (className.ToLower().Contains(singleBench.ToLower())) then
                ()
            else
                let mutable benchConfig = JsonElement()
                if not (Helper.Config.TryGetProperty(className, &benchConfig)) then
                    Console.WriteLine($"Skipping {className} - no config in test.js")
                else
                    Console.Write($"{className}: ")

                    Helper.Reset()

                    try
                        benchmark.Prepare()
                        benchmark.Warmup()

                        Helper.Reset()

                        let stopwatch = Stopwatch.StartNew()
                        benchmark.RunAll()
                        stopwatch.Stop()

                        let timeDelta = stopwatch.Elapsed.TotalSeconds
                        benchmark.TimeDelta <- timeDelta
                        results.[className] <- timeDelta

                        GC.Collect()
                        Thread.Sleep(0)
                        GC.Collect()

                        let actual = benchmark.Checksum
                        let expected = uint32 benchmark.ExpectedChecksum

                        if actual = expected then
                            Console.Write("OK ")
                            ok <- ok + 1
                        else
                            Console.Write($"ERR[actual={actual}, expected={expected}] ")
                            fails <- fails + 1

                        Console.WriteLine("in {0:F3}s", timeDelta)
                        summaryTime <- summaryTime + timeDelta
                    with
                    | ex -> 
                        Console.WriteLine($"ERROR: {ex.Message}")
                        fails <- fails + 1

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