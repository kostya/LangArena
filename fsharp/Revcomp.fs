namespace Benchmarks

open System
open System.IO
open System.Text

type Revcomp() =
    inherit Benchmark()

    let mutable n = 0L
    let mutable input = ""
    let mutable checksum = 0u

    static let lookupTable = 
        let table = Array.init 256 char
        let fromStr = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
        let toStr =   "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"

        for i in 0 .. fromStr.Length - 1 do
            table.[int fromStr.[i]] <- toStr.[i]
        table

    let reverseComplement (seq: string) =
        let length = seq.Length
        let lines = (length + 59) / 60
        let totalSize = length + lines

        let result = StringBuilder(totalSize)

        for start in length .. -60 .. 1 do
            let chunkStart = max (start - 60) 0
            let chunkSize = start - chunkStart

            for i in start - 1 .. -1 .. chunkStart do
                let c = seq.[i]
                result.Append(lookupTable.[int c]) |> ignore

            result.Append('\n') |> ignore

        if length % 60 = 0 && length > 0 then
            result.Length <- result.Length - 1

        result.ToString()

    override _.Checksum = checksum
    override this.Name = "CLBG::Revcomp"

    override _.Prepare() =
        n <- Helper.Config_i64("CLBG::Revcomp", "n")
        input <- ""
        checksum <- 0u

        let fastaResult = FastaShared.generateFastaSequence n

        let seqBuilder = StringBuilder()

        use reader = new StringReader(fastaResult)
        let rec readLines() =
            match reader.ReadLine() with
            | null -> ()
            | line ->
                if line.StartsWith(">") then
                    seqBuilder.Append("\n---\n") |> ignore
                else
                    seqBuilder.Append(line) |> ignore
                readLines()

        readLines()
        input <- seqBuilder.ToString()

    override _.Run(IterationId: int64) =
        checksum <- checksum + Helper.Checksum(reverseComplement input)