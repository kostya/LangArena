namespace Benchmarks

open System
open System.Text
open System.Collections.Generic

type Words() =
    inherit Benchmark()

    let mutable words = 0L
    let mutable wordLen = 0L
    let mutable text = ""
    let mutable checksumVal = 0u

    override this.Name = "Etc::Words"

    override this.Prepare() =
        words <- Helper.Config_i64("Etc::Words", "words")
        wordLen <- Helper.Config_i64("Etc::Words", "word_len")

        let chars = "abcdefghijklmnopqrstuvwxyz".ToCharArray()
        let charCount = chars.Length

        let words_list = ResizeArray<string>()

        for i in 0 .. (int words - 1) do
            let len = Helper.NextInt(wordLen |> int) + Helper.NextInt(3) + 3
            let wordChars = Array.zeroCreate len
            for j in 0 .. len - 1 do
                let idx = Helper.NextInt(charCount)
                wordChars.[j] <- chars.[idx]
            words_list.Add(String(wordChars))

        text <- String.Join(" ", words_list)

    override this.Run(iterationId: int64) =

        let frequencies = Dictionary<string, int>()

        for word in text.Split(' ') do
            if not (String.IsNullOrEmpty(word)) then
                match frequencies.TryGetValue(word) with
                | true, count -> frequencies.[word] <- count + 1
                | false, _ -> frequencies.[word] <- 1

        let mutable maxWord = ""
        let mutable maxCount = 0
        for kvp in frequencies do
            if kvp.Value > maxCount then
                maxCount <- kvp.Value
                maxWord <- kvp.Key

        let freqSize = uint32 frequencies.Count
        let wordChecksum = Helper.Checksum(maxWord)

        checksumVal <- checksumVal + (uint32 maxCount) + wordChecksum + freqSize

    override this.Checksum = checksumVal