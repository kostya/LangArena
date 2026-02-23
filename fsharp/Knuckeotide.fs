namespace Benchmarks

open System
open System.Collections.Generic
open System.IO
open System.Text

type Knuckeotide() =
    inherit Benchmark()

    let mutable n = 0L
    let mutable seq = ""
    let resultBuilder = StringBuilder()
    let mutable checksum = 0u

    let frequency (seq: string) length =
        let n = seq.Length - length + 1
        let table = Dictionary<string, int>()

        for i in 0 .. n - 1 do
            let sub = seq.Substring(i, length)
            match table.TryGetValue(sub) with
            | true, count -> table.[sub] <- count + 1
            | false, _ -> table.[sub] <- 1

        n, table

    let sortByFreq seq length =
        let n, table = frequency seq length

        let sorted = table |> Seq.sortByDescending (fun kv -> kv.Value)

        for kv in sorted do
            let freq = (float kv.Value * 100.0) / float n
            resultBuilder.AppendFormat("{0} {1:F3}\n", kv.Key.ToUpperInvariant(), freq) |> ignore

        resultBuilder.Append('\n') |> ignore

    let findSeq seq (s: string) =
        let n, table = frequency seq s.Length
        let count = match table.TryGetValue(s) with | true, c -> c | false, _ -> 0
        resultBuilder.AppendFormat("{0}\t{1}\n", count, s.ToUpperInvariant()) |> ignore

    override _.Checksum = 
        Helper.Checksum(resultBuilder.ToString())
    override this.Name = "CLBG::Knuckeotide"

    override _.Prepare() =
        n <- Helper.Config_i64("CLBG::Knuckeotide", "n")
        resultBuilder.Clear() |> ignore
        checksum <- 0u

        let fastaResult = FastaShared.generateFastaSequence n

        let seqBuilder = StringBuilder()
        let mutable three = false

        use reader = new StringReader(fastaResult)
        let rec readLines() =
            match reader.ReadLine() with
            | null -> ()
            | line ->
                if line.StartsWith(">THREE") then
                    three <- true
                elif three && not (line.StartsWith('>')) then
                    seqBuilder.Append(line.Trim()) |> ignore
                readLines()

        readLines()
        seq <- seqBuilder.ToString()

    override _.Run(IterationId: int64) =

        for i in 1 .. 2 do
            sortByFreq seq i

        let patterns = [|
            "ggt"; "ggta"; "ggtatt"; "ggtattttaatt"; "ggtattttaatttatagt"
        |]

        for pattern in patterns do
            findSeq seq pattern