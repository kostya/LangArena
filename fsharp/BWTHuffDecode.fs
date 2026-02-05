namespace Benchmarks

open System
open Benchmarks.Compression

type BWTHuffDecode() =
    inherit Benchmark()

    let mutable size = 0
    let mutable testData = Array.empty<byte>
    let mutable result = 0u
    let mutable compressedData: CompressedData option = None
    let mutable decompressed = Array.empty<byte>

    let generateTestData (size: int) =
        let pattern = "ABRACADABRA"B
        Array.init size (fun i -> pattern.[i % pattern.Length])

    override this.Checksum = 
        let mutable res = result
        if testData.Length > 0 && decompressed.Length > 0 then
            if testData = decompressed then
                res <- res + 1000000u
        res

    override this.Prepare() =
        size <- int (this.ConfigVal("size"))
        testData <- generateTestData size
        compressedData <- Some (Compression.compress testData)
        decompressed <- Array.empty<byte>
        result <- 0u

    override this.Run(_: int64) =
        match compressedData with
        | Some data ->
            decompressed <- Compression.decompress data
            result <- result + uint32 decompressed.Length
        | None -> ()