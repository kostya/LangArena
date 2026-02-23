namespace Benchmarks

open System
open System.Threading.Tasks

module MatmulCommon =
    let matGen (n: int) =
        let tmp = 1.0 / float n / float n
        Array.init n (fun i ->
            Array.init n (fun j ->
                tmp * float (i - j) * float (i + j)))

    let transpose (b: double[][]) =
        let n = b.Length
        Array.init n (fun i ->
            Array.init n (fun j -> b.[j].[i]))

    let matMulSingleThread (a: double[][]) (b: double[][]) =
        let n = a.Length
        let bT = transpose b

        Array.init n (fun i ->
            let ai = a.[i]
            Array.init n (fun j ->
                let bTj = bT.[j]
                let mutable sum = 0.0

                for k = 0 to n - 1 do
                    sum <- sum + ai.[k] * bTj.[k]
                sum))

    let matMulMultiThread (threads: int) (a: double[][]) (b: double[][]) =
        let n = a.Length
        let bT = transpose b
        let c = Array.init n (fun _ -> Array.zeroCreate<double> n)

        let options = ParallelOptions(MaxDegreeOfParallelism = threads)

        Parallel.For(0, n, options, fun i ->
            let ai = a.[i]
            let ci = c.[i]

            for j = 0 to n - 1 do
                let bTj = bT.[j]
                let mutable sum = 0.0

                for k = 0 to n - 1 do
                    sum <- sum + ai.[k] * bTj.[k]

                ci.[j] <- sum
            ) |> ignore

        c

[<AbstractClass>]
type MatmulBase(name: string) =
    inherit Benchmark()

    let mutable n = 0
    let mutable result = 0u
    let mutable a : double[][] = null
    let mutable b : double[][] = null

    override this.Checksum = result
    override this.Name = name

    override this.Prepare() =
        n <- int (this.ConfigVal("n"))
        a <- MatmulCommon.matGen n
        b <- MatmulCommon.matGen n
        result <- 0u

    member this.N = n
    member this.A = a
    member this.B = b
    member this.Result with get() = result and set(value) = result <- value

type Matmul1T() =
    inherit MatmulBase("Matmul::Single")

    override this.Run(_: int64) =
        let c = MatmulCommon.matMulSingleThread this.A this.B
        let value = c.[this.N >>> 1].[this.N >>> 1]
        this.Result <- this.Result + Helper.Checksum(value)

type Matmul4T() =
    inherit MatmulBase("Matmul::T4")

    override this.Run(_: int64) =
        let c = MatmulCommon.matMulMultiThread 4 this.A this.B
        let value = c.[this.N >>> 1].[this.N >>> 1]
        this.Result <- this.Result + Helper.Checksum(value)

type Matmul8T() =
    inherit MatmulBase("Matmul::T8")

    override this.Run(_: int64) =
        let c = MatmulCommon.matMulMultiThread 8 this.A this.B
        let value = c.[this.N >>> 1].[this.N >>> 1]
        this.Result <- this.Result + Helper.Checksum(value)

type Matmul16T() =
    inherit MatmulBase("Matmul::T16")

    override this.Run(_: int64) =
        let c = MatmulCommon.matMulMultiThread 16 this.A this.B
        let value = c.[this.N >>> 1].[this.N >>> 1]
        this.Result <- this.Result + Helper.Checksum(value)