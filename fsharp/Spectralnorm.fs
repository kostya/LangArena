namespace Benchmarks

open System

type Spectralnorm() =
    inherit Benchmark()

    let mutable size = 0L
    let mutable u = Array.empty<double>
    let mutable v = Array.empty<double>

    let evalA i j =
        1.0 / ((double i + double j) * (double i + double j + 1.0) / 2.0 + double i + 1.0)

    member private _.EvalA(i, j) = evalA i j

    member private _.EvalATimesU(uArr: double[]) =
        let length = uArr.Length
        let result = Array.zeroCreate<double> length

        for i in 0 .. length - 1 do
            let mutable sum = 0.0
            for j in 0 .. length - 1 do
                sum <- sum + evalA i j * uArr.[j]
            result.[i] <- sum

        result

    member private _.EvalAtTimesU(uArr: double[]) =
        let length = uArr.Length
        let result = Array.zeroCreate<double> length

        for i in 0 .. length - 1 do
            let mutable sum = 0.0
            for j in 0 .. length - 1 do
                sum <- sum + evalA j i * uArr.[j]
            result.[i] <- sum

        result

    member private this.EvalAtATimesU(uArr: double[]) = 
        let temp = this.EvalATimesU uArr
        this.EvalAtTimesU temp

    override this.Prepare() =
        size <- this.ConfigVal("size")
        let n = int size
        u <- Array.create n 1.0
        v <- Array.create n 1.0

    override this.Run(_: int64) =
        v <- this.EvalAtATimesU u
        u <- this.EvalAtATimesU v

    override this.Checksum =
        let mutable vBv = 0.0
        let mutable vv = 0.0

        for i in 0 .. (int size) - 1 do
            vBv <- vBv + u.[i] * v.[i]
            vv <- vv + v.[i] * v.[i]

        Helper.Checksum (Math.Sqrt(vBv / vv))