namespace Benchmarks

open System
open System.Text

module FastaShared =
    let LINE_LENGTH = 60

    let IUB = [|
        ('a', 0.27); ('c', 0.39); ('g', 0.51); ('t', 0.78)
        ('B', 0.8); ('D', 0.8200000000000001); ('H', 0.8400000000000001)
        ('K', 0.8600000000000001); ('M', 0.8800000000000001)
        ('N', 0.9000000000000001); ('R', 0.9200000000000002)
        ('S', 0.9400000000000002); ('V', 0.9600000000000002)
        ('W', 0.9800000000000002); ('Y', 1.0000000000000002)
    |]

    let HOMO = [|
        ('a', 0.302954942668); ('c', 0.5009432431601)
        ('g', 0.6984905497992); ('t', 1.0)
    |]

    let ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

    let selectRandom (genelist: (char * float)[]) =
        let r = Helper.NextFloat(1.0)
        if r < (snd genelist.[0]) then fst genelist.[0] else

        let rec binarySearch lo hi =
            if hi > lo + 1 then
                let i = (hi + lo) / 2
                if r < (snd genelist.[i]) then binarySearch lo i
                else binarySearch i hi
            else fst genelist.[hi]

        binarySearch 0 (genelist.Length - 1)

    let makeRandomFasta (resultBuilder: StringBuilder) id desc genelist n =
        resultBuilder.AppendFormat(">{0} {1}\n", id, desc) |> ignore

        let rec loop todo =
            if todo > 0 then
                let m = min todo LINE_LENGTH
                let buffer = Array.zeroCreate<char> m

                for i in 0 .. m - 1 do
                    buffer.[i] <- selectRandom genelist

                resultBuilder.Append(buffer, 0, m) |> ignore
                resultBuilder.Append('\n') |> ignore
                loop (todo - LINE_LENGTH)

        loop n

    let makeRepeatFasta (resultBuilder: StringBuilder) id desc (s: string) n =
        resultBuilder.AppendFormat(">{0} {1}\n", id, desc) |> ignore

        let kn = s.Length
        let rec loop todo k =
            if todo > 0 then
                let m = min todo LINE_LENGTH

                let rec writeChunk remaining k =
                    if remaining > 0 then
                        let available = kn - k
                        if remaining >= available then
                            resultBuilder.Append(s, k, available) |> ignore
                            writeChunk (remaining - available) 0
                        else
                            resultBuilder.Append(s, k, remaining) |> ignore
                            k + remaining
                    else k

                let newK = writeChunk m k
                resultBuilder.Append('\n') |> ignore
                loop (todo - LINE_LENGTH) newK

        loop n 0

    let generateFastaSequence n =
        let resultBuilder = StringBuilder()

        makeRepeatFasta resultBuilder "ONE" "Homo sapiens alu" ALU (int (n * 2L))
        makeRandomFasta resultBuilder "TWO" "IUB ambiguity codes" IUB (int (n * 3L))
        makeRandomFasta resultBuilder "THREE" "Homo sapiens frequency" HOMO (int (n * 5L))

        resultBuilder.ToString()