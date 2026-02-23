namespace Benchmarks

open System
open System.Numerics
open System.Text

type Pidigits() =
    inherit Benchmark()

    let mutable nn = 0
    let mutable resultBuilder = StringBuilder()

    override this.Run(_: int64) =
        let mutable i = 0
        let mutable k = 0
        let mutable ns = 0UL
        let mutable a = BigInteger.Zero
        let mutable k1 = 1
        let mutable n = BigInteger.One
        let mutable d = BigInteger.One
        let mutable finished = false

        while not finished do
            k <- k + 1
            let t = n <<< 1
            n <- n * BigInteger k
            k1 <- k1 + 2
            a <- (a + t) * BigInteger k1
            d <- d * BigInteger k1

            if a >= n then
                let temp = n * BigInteger 3 + a
                let quotient = temp / d
                let t2 = quotient
                let u = temp % d
                let u2 = u + n

                if d > u2 then
                    ns <- ns * 10UL + (uint64 t2)
                    i <- i + 1

                    if i % 10 = 0 then
                        resultBuilder.AppendFormat("{0:D10}\t:{1}\n", ns, i) |> ignore
                        ns <- 0UL

                    if i >= nn then
                        if ns <> 0UL then
                            resultBuilder.AppendFormat("{0:D10}\t:{1}\n", ns, i) |> ignore
                        finished <- true
                    else
                        a <- (a - (d * t2)) * BigInteger 10
                        n <- n * BigInteger 10

    override this.Checksum = 
        Helper.Checksum(resultBuilder.ToString())
    override this.Name = "CLBG::Pidigits"

    override this.Prepare() =
        nn <- Helper.Config_i64("CLBG::Pidigits", "amount") |> int
        resultBuilder <- StringBuilder()