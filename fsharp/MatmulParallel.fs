namespace Benchmarks

open System
open System.Threading.Tasks

module MatmulCommon =
    let matGen (n: int) =
        let tmp = 1.0 / float n / float n
        Array.init n (fun i ->
            Array.init n (fun j ->
                tmp * float (i - j) * float (i + j)))

    let matMulSingleThread (a: double[][]) (b: double[][]) =
        let size = a.Length
        let bT = Array.init size (fun i ->
            Array.init size (fun j -> b.[j].[i]))

        Array.init size (fun i ->
            let ai = a.[i]
            Array.init size (fun j ->
                let bTj = bT.[j]
                let mutable sum = 0.0
                for k = 0 to size - 1 do
                    sum <- sum + ai.[k] * bTj.[k]
                sum))

    let matMulMultiThread (threads: int) (a: double[][]) (b: double[][]) =
        let size = a.Length
        let bT = Array.init size (fun i ->
            Array.init size (fun j -> b.[j].[i]))

        let c = Array.init size (fun _ -> Array.zeroCreate<double> size)

        let options = ParallelOptions(MaxDegreeOfParallelism = threads)

        Parallel.For(0, size, options, fun i ->
            let ai = a.[i]
            let ci = c.[i]

            for j = 0 to size - 1 do
                let bTj = bT.[j]
                let mutable sum = 0.0

                for k = 0 to size - 1 do
                    sum <- sum + ai.[k] * bTj.[k]

                ci.[j] <- sum
            ) |> ignore

        c

type Matmul1T() =
    inherit Benchmark()

    let mutable n = 0
    let mutable result = 0u

    override this.Checksum = result

    override this.Prepare() =
        n <- int (this.ConfigVal("n"))
        result <- 0u

    override this.Run(_: int64) =
        let a = MatmulCommon.matGen n
        let b = MatmulCommon.matGen n
        let c = MatmulCommon.matMulSingleThread a b

        let value = c.[n >>> 1].[n >>> 1]
        result <- result + Helper.Checksum(value)

type Matmul4T() =
    inherit Benchmark()

    let mutable n = 0
    let mutable result = 0u

    override this.Checksum = result

    override this.Prepare() =
        n <- int (this.ConfigVal("n"))
        result <- 0u

    override this.Run(_: int64) =
        let a = MatmulCommon.matGen n
        let b = MatmulCommon.matGen n
        let c = MatmulCommon.matMulMultiThread 4 a b

        let value = c.[n >>> 1].[n >>> 1]
        result <- result + Helper.Checksum(value)

type Matmul8T() =
    inherit Benchmark()

    let mutable n = 0
    let mutable result = 0u

    override this.Checksum = result

    override this.Prepare() =
        n <- int (this.ConfigVal("n"))
        result <- 0u

    override this.Run(_: int64) =
        let a = MatmulCommon.matGen n
        let b = MatmulCommon.matGen n
        let c = MatmulCommon.matMulMultiThread 8 a b

        let value = c.[n >>> 1].[n >>> 1]
        result <- result + Helper.Checksum(value)

type Matmul16T() =
    inherit Benchmark()

    let mutable n = 0
    let mutable result = 0u

    override this.Checksum = result

    override this.Prepare() =
        n <- int (this.ConfigVal("n"))
        result <- 0u

    override this.Run(_: int64) =
        let a = MatmulCommon.matGen n
        let b = MatmulCommon.matGen n
        let c = MatmulCommon.matMulMultiThread 16 a b

        let value = c.[n >>> 1].[n >>> 1]
        result <- result + Helper.Checksum(value)