namespace Benchmarks

open System
open System.IO
open System.Text
open System.Text.RegularExpressions

type RegexDna() =
    inherit Benchmark()

    let mutable n = 0L
    let mutable seq = ""
    let mutable ilen = 0
    let mutable clen = 0
    let resultBuilder = StringBuilder()
    let mutable checksum = 0u

    let patterns = [|
        "agggtaaa|tttaccct"
        "[cgt]gggtaaa|tttaccc[acg]"
        "a[act]ggtaaa|tttacc[agt]t"
        "ag[act]gtaaa|tttac[agt]ct"
        "agg[act]taaa|ttta[agt]cct"
        "aggg[acg]aaa|ttt[cgt]ccct"
        "agggt[cgt]aa|tt[acg]accct"
        "agggta[cgt]a|t[acg]taccct"
        "agggtaa[cgt]|[acg]ttaccct"
    |]

    let replacements = dict [
        "B", "(c|g|t)"
        "D", "(a|g|t)"
        "H", "(a|c|t)"
        "K", "(g|t)"
        "M", "(a|c)"
        "N", "(a|c|g|t)"
        "R", "(a|g)"
        "S", "(c|t)"
        "V", "(a|c|g)"
        "W", "(a|t)"
        "Y", "(c|t)"
    ]

    override _.Checksum = checksum
    override this.Name = "CLBG::RegexDna"

    override _.Prepare() =
        n <- Helper.Config_i64("CLBG::RegexDna", "n")
        resultBuilder.Clear() |> ignore
        checksum <- 0u

        let fastaResult = FastaShared.generateFastaSequence n

        let seqBuilder = StringBuilder()
        ilen <- 0

        use reader = new StringReader(fastaResult)
        let rec readLines() =
            match reader.ReadLine() with
            | null -> ()
            | line ->
                ilen <- ilen + line.Length + 1
                if not (line.StartsWith('>')) then
                    seqBuilder.Append(line) |> ignore
                readLines()

        readLines()
        seq <- seqBuilder.ToString()
        clen <- seqBuilder.Length

    override _.Run(IterationId: int64) =

        let compiledPatterns = patterns |> Array.map (fun p -> Regex(p, RegexOptions.Compiled))

        for regex in compiledPatterns do
            let count = regex.Matches(seq).Count
            resultBuilder.AppendFormat("{0} {1}\n", regex.ToString(), count) |> ignore

        let mutable newSeq = seq
        for kv in replacements do
            newSeq <- Regex.Replace(newSeq, kv.Key, kv.Value)

        resultBuilder.AppendFormat("\n{0}\n{1}\n{2}\n", ilen, clen, newSeq.Length) |> ignore

        checksum <- Helper.Checksum(resultBuilder.ToString())