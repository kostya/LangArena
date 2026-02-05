open System
open Benchmarks
open System.Globalization
open System.Threading

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

    Benchmark.All(defaultArg singleBench null)

    0 