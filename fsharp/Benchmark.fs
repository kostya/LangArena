namespace Benchmarks

open System
open System.Collections.Generic
open System.Diagnostics
open System.IO
open System.Reflection
open System.Text.Json
open System.Threading

[<AbstractClass>]
type Benchmark() =
    abstract member Run: int64 -> unit
    abstract member Checksum: uint32
    abstract member Prepare: unit -> unit
    default _.Prepare() = ()

    abstract member Warmup: unit -> unit
    default this.Warmup() =
        let prepareIters = this.WarmupIterations
        for i in 0L .. prepareIters - 1L do
            this.Run(i)

    member val TimeDelta = 0.0 with get, set

    member this.Name = this.GetType().Name

    member this.WarmupIterations : int64 =
        let className = this.Name
        let mutable benchObj = JsonElement()
        if Helper.Config.TryGetProperty(className, &benchObj) then
            let mutable warmupProp = JsonElement()
            if benchObj.TryGetProperty("warmup_iterations", &warmupProp) then
                warmupProp.GetInt64()
            else
                let iters = this.Iterations
                max (int64 (double iters * 0.2)) 1L
        else
            let iters = this.Iterations
            max (int64 (double iters * 0.2)) 1L

    member this.RunAll() =
        let iters = this.Iterations
        for i in 0L .. iters - 1L do
            this.Run(i)

    member this.ConfigVal(fieldName: string) : int64 =
        Helper.Config_i64(this.Name, fieldName)

    member this.Iterations : int64 = this.ConfigVal("iterations")

    member this.ExpectedChecksum : int64 = this.ConfigVal("checksum")

    static member All(?singleBench: string) =
        let singleBench = defaultArg singleBench null

        let now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        printfn "start: %d" now

        let results = Dictionary<string, double>()
        let mutable summaryTime = 0.0
        let mutable ok = 0
        let mutable fails = 0

        let assembly = Assembly.GetExecutingAssembly()
        let benchmarkTypes = 
            assembly.GetTypes()
            |> Array.filter (fun t -> 
                t.IsSubclassOf(typeof<Benchmark>) && not t.IsAbstract)

        let benchmarks = 
            benchmarkTypes
            |> Array.map (fun t -> Activator.CreateInstance(t) :?> Benchmark)
            |> Array.toList

        for benchmark in benchmarks do
            let className = benchmark.Name

            if not (String.IsNullOrEmpty singleBench) && 
               not (className.ToLower().Contains(singleBench.ToLower())) then
                ()
            else
                let mutable benchConfig = JsonElement()
                if not (Helper.Config.TryGetProperty(className, &benchConfig)) then
                    printfn "Skipping %s - no config in test.js" className
                else
                    printf "%s: " className

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
                            printf "OK "
                            ok <- ok + 1
                        else
                            printf "ERR[actual=%d, expected=%d] " actual expected
                            fails <- fails + 1

                        printfn "in %.3fs" timeDelta
                        summaryTime <- summaryTime + timeDelta
                    with
                    | ex -> 
                        printfn "ERROR: %s" ex.Message
                        fails <- fails + 1

        try
            let json = "{" + String.Join(",", results |> Seq.map (fun kv -> sprintf "\"%s\":%f" kv.Key kv.Value)) + "}"
            File.WriteAllText("/tmp/results.js", json)
        with
        | ex -> printfn "Error saving results: %s" ex.Message

        printfn "Summary: %.4fs, %d, %d, %d" summaryTime (ok + fails) ok fails

        File.WriteAllText("/tmp/recompile_marker", "RECOMPILE_MARKER_0")

        if fails > 0 || ok = 0 then
            Environment.Exit(1)