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