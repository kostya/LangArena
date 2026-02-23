namespace Benchmarks

open System
open System.Text

type Fasta() =
    inherit Benchmark()

    let mutable n = 0L
    let resultBuilder = StringBuilder()

    override _.Run(IterationId: int64) =
        FastaShared.makeRepeatFasta resultBuilder "ONE" "Homo sapiens alu" FastaShared.ALU (int (n * 2L))
        FastaShared.makeRandomFasta resultBuilder "TWO" "IUB ambiguity codes" FastaShared.IUB (int (n * 3L))
        FastaShared.makeRandomFasta resultBuilder "THREE" "Homo sapiens frequency" FastaShared.HOMO (int (n * 5L))

    override _.Checksum = Helper.Checksum(resultBuilder.ToString())
    override this.Name = "CLBG::Fasta"

    override _.Prepare() =
        n <- Helper.Config_i64("CLBG::Fasta", "n")
        resultBuilder.Clear() |> ignore

    member _.GetResult() = resultBuilder.ToString()