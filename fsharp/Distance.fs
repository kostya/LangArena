namespace Benchmarks

open System
open System.Collections.Generic
open System.Text

module Distance =
    let generatePairStrings (n: int) (m: int) =
        let chars = "abcdefghij".ToCharArray()
        let pairs = ResizeArray<(string * string)>()
        let rnd = Random()

        for i in 0 .. n-1 do
            let len1 = Helper.NextInt(m) + 4
            let len2 = Helper.NextInt(m) + 4

            let str1 = StringBuilder(len1)
            let str2 = StringBuilder(len2)

            for j in 0 .. len1-1 do
                str1.Append(chars.[Helper.NextInt(10)]) |> ignore
            for j in 0 .. len2-1 do
                str2.Append(chars.[Helper.NextInt(10)]) |> ignore

            pairs.Add((str1.ToString(), str2.ToString()))

        pairs.ToArray()

type Jaro() =
    inherit Benchmark()

    let mutable count = 0L
    let mutable size = 0L
    let mutable pairs = [||]
    let mutable resultVal = 0u

    override this.Name = "Distance::Jaro"

    override this.Prepare() =
        count <- this.ConfigVal("count")
        size <- this.ConfigVal("size")
        pairs <- Distance.generatePairStrings (int count) (int size)
        resultVal <- 0u

    member private this.CalcJaro(s1: string, s2: string) =

        let bytes1 = Text.Encoding.ASCII.GetBytes(s1)
        let bytes2 = Text.Encoding.ASCII.GetBytes(s2)

        let len1 = bytes1.Length
        let len2 = bytes2.Length

        if len1 = 0 || len2 = 0 then 0.0
        else
            let matchDist = (max len1 len2) / 2 - 1
            let matchDist = if matchDist < 0 then 0 else matchDist

            let s1Matches = Array.create len1 false
            let s2Matches = Array.create len2 false

            let mutable matches = 0
            for i in 0 .. len1-1 do
                let start' = max 0 (i - matchDist)  
                let end' = min (len2 - 1) (i + matchDist)

                let mutable j = start'
                while j <= end' && not (not s2Matches.[j] && bytes1.[i] = bytes2.[j]) do
                    j <- j + 1
                if j <= end' then
                    s1Matches.[i] <- true
                    s2Matches.[j] <- true
                    matches <- matches + 1

            if matches = 0 then 0.0
            else
                let mutable transpositions = 0
                let mutable k = 0
                for i in 0 .. len1-1 do
                    if s1Matches.[i] then
                        while k < len2 && not s2Matches.[k] do
                            k <- k + 1
                        if k < len2 then
                            if bytes1.[i] <> bytes2.[k] then
                                transpositions <- transpositions + 1
                            k <- k + 1

                transpositions <- transpositions / 2

                let m = double matches
                (m / double len1 + m / double len2 + (m - double transpositions) / m) / 3.0

    override this.Run(iterationId: int64) =
        for (s1, s2) in pairs do
            resultVal <- resultVal + uint32 (this.CalcJaro(s1, s2) * 1000.0)

    override this.Checksum =
        resultVal

type NGram() =
    inherit Benchmark()

    let mutable count = 0L
    let mutable size = 0L
    let mutable pairs = [||]
    let mutable resultVal = 0u
    let N = 4

    override this.Name = "Distance::NGram"

    override this.Prepare() =
        count <- this.ConfigVal("count")
        size <- this.ConfigVal("size")
        pairs <- Distance.generatePairStrings (int count) (int size)
        resultVal <- 0u

    member private this.CalcNGram(s1: string, s2: string) =

        let bytes1 = Text.Encoding.ASCII.GetBytes(s1)
        let bytes2 = Text.Encoding.ASCII.GetBytes(s2)

        if bytes1.Length < N || bytes2.Length < N then 0.0
        else
            let grams1 = Dictionary<uint32, int>(bytes1.Length)  

            for i in 0 .. bytes1.Length - N do
                let gram = (uint32 bytes1.[i] <<< 24) |||
                           (uint32 bytes1.[i + 1] <<< 16) |||
                           (uint32 bytes1.[i + 2] <<< 8) |||
                            uint32 bytes1.[i + 3]

                match grams1.TryGetValue(gram) with
                | true, cnt -> grams1.[gram] <- cnt + 1
                | false, _ -> grams1.[gram] <- 1

            let grams2 = Dictionary<uint32, int>(bytes2.Length)
            let mutable intersection = 0

            for i in 0 .. bytes2.Length - N do
                let gram = (uint32 bytes2.[i] <<< 24) |||
                           (uint32 bytes2.[i + 1] <<< 16) |||
                           (uint32 bytes2.[i + 2] <<< 8) |||
                            uint32 bytes2.[i + 3]

                match grams2.TryGetValue(gram) with
                | true, cnt -> grams2.[gram] <- cnt + 1
                | false, _ -> grams2.[gram] <- 1

                match grams1.TryGetValue(gram) with
                | true, cnt1 when grams2.[gram] <= cnt1 ->
                    intersection <- intersection + 1
                | _ -> ()

            let total = grams1.Count + grams2.Count
            if total > 0 then double intersection / double total else 0.0

    override this.Run(iterationId: int64) =
        for (s1, s2) in pairs do
            let v = uint32 (this.CalcNGram(s1, s2) * 1000.0)
            resultVal <- (resultVal + v) &&& 0xFFFFFFFFu
    override this.Checksum =
        resultVal