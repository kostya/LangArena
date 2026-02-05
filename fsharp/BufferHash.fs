namespace Benchmarks

open System

module HashAlgorithms =
    module SHA256Like =
        let private initialHashes = [|
            0x6a09e667u
            0xbb67ae85u
            0x3c6ef372u
            0xa54ff53au
            0x510e527fu
            0x9b05688cu
            0x1f83d9abu
            0x5be0cd19u
        |]

        let compute (data: byte[]) =
            let hashes = Array.copy initialHashes

            data
            |> Array.iteri (fun i b ->
                let hashIdx = i % 8
                let b = uint32 b

                let hash = 
                    hashes.[hashIdx]
                    |> fun h -> ((h <<< 5) + h) + b
                    |> fun h -> h &&& 0xFFFFFFFFu
                    |> fun h -> (h + (h <<< 10)) ^^^ (h >>> 6)
                    |> fun h -> h &&& 0xFFFFFFFFu

                hashes.[hashIdx] <- hash)

            let result = Array.zeroCreate<byte> 32

            for i = 0 to 7 do
                let hash = hashes.[i]
                result.[i * 4] <- byte ((hash >>> 24) &&& 0xFFu)
                result.[i * 4 + 1] <- byte ((hash >>> 16) &&& 0xFFu)
                result.[i * 4 + 2] <- byte ((hash >>> 8) &&& 0xFFu)
                result.[i * 4 + 3] <- byte (hash &&& 0xFFu)

            (uint32 result.[0]) |||
            (uint32 result.[1] <<< 8) |||
            (uint32 result.[2] <<< 16) |||
            (uint32 result.[3] <<< 24)

    module CRC32 =
        let compute (data: byte[]) =
            let mutable crc = 0xFFFFFFFFu

            for b in data do
                crc <- crc ^^^ (uint32 b)

                for _ = 1 to 8 do
                    if (crc &&& 1u) <> 0u then
                        crc <- (crc >>> 1) ^^^ 0xEDB88320u
                    else
                        crc <- crc >>> 1

            crc ^^^ 0xFFFFFFFFu

[<AbstractClass>]
type BufferHashBenchmark() =
    inherit Benchmark()

    let mutable data = Array.empty<byte>
    let mutable result = 0u

    member _.Data = data
    member _.UpdateResult value = result <- result + value

    override this.Prepare() =
        let n = int (this.ConfigVal("size"))
        data <- Array.init n (fun _ -> byte (Helper.NextInt(256)))
        result <- 0u

    override this.Checksum = result

    abstract member ComputeHash: byte[] -> uint32

    override this.Run(_: int64) =
        let hashValue = this.ComputeHash(data)
        this.UpdateResult hashValue

type BufferHashSHA256() =
    inherit BufferHashBenchmark()

    override _.ComputeHash(data: byte[]) = HashAlgorithms.SHA256Like.compute data

type BufferHashCRC32() =
    inherit BufferHashBenchmark()

    override _.ComputeHash(data: byte[]) = HashAlgorithms.CRC32.compute data