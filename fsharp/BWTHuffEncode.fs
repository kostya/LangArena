namespace Benchmarks

open System
open System.Collections.Generic

[<Struct>]
type BWTResult = 
    { 
        Transformed: byte[]
        OriginalIdx: int 
    }

type HuffmanNode(frequency: int, byteVal: byte, isLeaf: bool, left: HuffmanNode, right: HuffmanNode) =
    let mutable freq = frequency
    let mutable bval = byteVal
    let mutable leaf = isLeaf
    let mutable l = left
    let mutable r = right

    new(frequency: int, byteVal: byte) = 
        HuffmanNode(frequency, byteVal, true, Unchecked.defaultof<HuffmanNode>, Unchecked.defaultof<HuffmanNode>)

    member this.Frequency = freq
    member this.ByteVal = bval
    member this.IsLeaf = leaf
    member this.Left = l
    member this.Right = r

    member this.SetLeft(node: HuffmanNode) = l <- node
    member this.SetRight(node: HuffmanNode) = r <- node
    member this.SetIsLeaf(value: bool) = leaf <- value

type HuffmanCodesStruct() =
    let codeLengths = Array.zeroCreate<int> 256
    let codes = Array.zeroCreate<int> 256

    member _.CodeLengths = codeLengths
    member _.Codes = codes

type EncodedResult = 
    { 
        Data: byte[]
        BitCount: int 
    }

type CompressedData = 
    { 
        BwtResult: BWTResult
        Frequencies: int[]
        EncodedBits: byte[]
        OriginalBitCount: int 
    }

module BWT =
    let transform (input: byte[]) : BWTResult =
        let n = input.Length
        if n = 0 then { Transformed = [||]; OriginalIdx = 0 }
        else

            let sa = Array.init n id

            let bucketLists = Array.init 256 (fun _ -> List<int>())
            for i = 0 to n - 1 do
                bucketLists.[int input.[i]].Add(i)

            let mutable pos = 0
            for bucket in bucketLists do
                for idx in bucket do
                    sa.[pos] <- idx
                    pos <- pos + 1

            if n > 1 then

                let rank = Array.zeroCreate<int> n
                let mutable currentRank = 0
                let mutable prevChar = input.[sa.[0]]

                for i = 0 to n - 1 do
                    let idx = sa.[i]
                    let currChar = input.[idx]
                    if currChar <> prevChar then
                        currentRank <- currentRank + 1
                        prevChar <- currChar
                    rank.[idx] <- currentRank

                let mutable k = 1
                while k < n do

                    let pairs = Array.zeroCreate<int * int> n
                    for i = 0 to n - 1 do
                        pairs.[i] <- (rank.[i], rank.[(i + k) % n])

                    let comparer = 
                        { new IComparer<int> with
                            member _.Compare(a, b) =
                                let (a1, a2) = pairs.[a]
                                let (b1, b2) = pairs.[b]
                                if a1 <> b1 then compare a1 b1
                                else compare a2 b2 }

                    Array.Sort(sa, comparer)

                    let newRank = Array.zeroCreate<int> n
                    newRank.[sa.[0]] <- 0

                    for i = 1 to n - 1 do
                        let prevPair = pairs.[sa.[i - 1]]
                        let currPair = pairs.[sa.[i]]
                        newRank.[sa.[i]] <- 
                            newRank.[sa.[i - 1]] + 
                            (if prevPair <> currPair then 1 else 0)

                    Array.blit newRank 0 rank 0 n
                    k <- k * 2

            let transformed = Array.zeroCreate<byte> n
            let mutable originalIdx = 0

            for i = 0 to n - 1 do
                let suffix = sa.[i]
                if suffix = 0 then
                    transformed.[i] <- input.[n - 1]
                    originalIdx <- i
                else
                    transformed.[i] <- input.[suffix - 1]

            { Transformed = transformed; OriginalIdx = originalIdx }

    let inverse (bwtResult: BWTResult) : byte[] =
        let bwt = bwtResult.Transformed
        let n = bwt.Length
        if n = 0 then [||]
        else

            let counts = Array.zeroCreate<int> 256
            for b in bwt do counts.[int b] <- counts.[int b] + 1

            let positions = Array.zeroCreate<int> 256
            let mutable total = 0
            for i = 0 to 255 do
                positions.[i] <- total
                total <- total + counts.[i]

            let next = Array.zeroCreate<int> n
            let tempCounts = Array.copy counts
            Array.fill tempCounts 0 256 0

            for i = 0 to n - 1 do
                let byteIdx = int bwt.[i]
                let pos = positions.[byteIdx] + tempCounts.[byteIdx]
                next.[pos] <- i
                tempCounts.[byteIdx] <- tempCounts.[byteIdx] + 1

            let result = Array.zeroCreate<byte> n
            let mutable idx = bwtResult.OriginalIdx

            for i = 0 to n - 1 do
                idx <- next.[idx]
                result.[i] <- bwt.[idx]

            result

module Huffman =
    let buildTree (frequencies: int[]) : HuffmanNode =
        let heap = PriorityQueue<HuffmanNode, int>()

        for i = 0 to frequencies.Length - 1 do
            if frequencies.[i] > 0 then
                heap.Enqueue(HuffmanNode(frequencies.[i], byte i), frequencies.[i])

        if heap.Count = 1 then
            let node = heap.Dequeue()
            let newNode = HuffmanNode(node.Frequency, 0uy, false, node, HuffmanNode(0, 0uy))
            newNode
        else
            while heap.Count > 1 do
                let left = heap.Dequeue()
                let right = heap.Dequeue()

                let parent = HuffmanNode(left.Frequency + right.Frequency, 0uy, false, left, right)
                heap.Enqueue(parent, parent.Frequency)

            heap.Dequeue()

    let buildCodes (node: HuffmanNode) : HuffmanCodesStruct =
        let huffmanCodes = HuffmanCodesStruct()

        let rec traverse (node: HuffmanNode) (code: int) (length: int) =
            if node.IsLeaf && node.ByteVal <> 0uy then
                let idx = int node.ByteVal
                huffmanCodes.CodeLengths.[idx] <- length
                huffmanCodes.Codes.[idx] <- code
            else
                if node.Left <> Unchecked.defaultof<HuffmanNode> then
                    traverse node.Left (code <<< 1) (length + 1)
                if node.Right <> Unchecked.defaultof<HuffmanNode> then
                    traverse node.Right ((code <<< 1) ||| 1) (length + 1)

        traverse node 0 0
        huffmanCodes

    let encode (data: byte[]) (codes: HuffmanCodesStruct) : EncodedResult =
        let result = Array.zeroCreate<byte> (data.Length * 2)
        let mutable currentByte = 0uy
        let mutable bitPos = 0
        let mutable byteIndex = 0
        let mutable totalBits = 0

        for b in data do
            let idx = int b
            let code = codes.Codes.[idx]
            let length = codes.CodeLengths.[idx]

            for i = length - 1 downto 0 do
                if (code &&& (1 <<< i)) <> 0 then
                    currentByte <- currentByte ||| (1uy <<< (7 - bitPos))

                bitPos <- bitPos + 1
                totalBits <- totalBits + 1

                if bitPos = 8 then
                    result.[byteIndex] <- currentByte
                    byteIndex <- byteIndex + 1
                    currentByte <- 0uy
                    bitPos <- 0

        if bitPos > 0 then
            result.[byteIndex] <- currentByte
            byteIndex <- byteIndex + 1

        { 
            Data = if byteIndex = result.Length then result else Array.sub result 0 byteIndex
            BitCount = totalBits 
        }

    let decode (encoded: byte[]) (root: HuffmanNode) (bitCount: int) : byte[] =
        let result = List<byte>()
        let mutable currentNode = root
        let mutable bitsProcessed = 0
        let mutable byteIndex = 0

        while bitsProcessed < bitCount && byteIndex < encoded.Length do
            let byteVal = encoded.[byteIndex]
            byteIndex <- byteIndex + 1

            for bitPos = 7 downto 0 do
                if bitsProcessed < bitCount then
                    let bit = ((byteVal >>> bitPos) &&& 1uy) = 1uy
                    bitsProcessed <- bitsProcessed + 1

                    currentNode <- if bit then currentNode.Right else currentNode.Left

                    if currentNode.IsLeaf && currentNode.ByteVal <> 0uy then
                        result.Add(currentNode.ByteVal)
                        currentNode <- root

        result.ToArray()

module Compression =
    let compress (data: byte[]) : CompressedData =
        let bwtResult = BWT.transform data

        let frequencies = Array.zeroCreate<int> 256
        for b in bwtResult.Transformed do
            frequencies.[int b] <- frequencies.[int b] + 1

        let huffmanTree = Huffman.buildTree frequencies
        let huffmanCodes = Huffman.buildCodes huffmanTree
        let encoded = Huffman.encode bwtResult.Transformed huffmanCodes

        { 
            BwtResult = bwtResult
            Frequencies = frequencies
            EncodedBits = encoded.Data
            OriginalBitCount = encoded.BitCount 
        }

    let decompress (compressed: CompressedData) : byte[] =
        let huffmanTree = Huffman.buildTree compressed.Frequencies
        let decoded = Huffman.decode compressed.EncodedBits huffmanTree compressed.OriginalBitCount
        let bwtResult = { Transformed = decoded; OriginalIdx = compressed.BwtResult.OriginalIdx }
        BWT.inverse bwtResult

type BWTHuffEncode() =
    inherit Benchmark()

    let mutable size = 0
    let mutable testData = Array.empty<byte>
    let mutable result = 0u

    let generateTestData (size: int) =
        let pattern = "ABRACADABRA"B
        Array.init size (fun i -> pattern.[i % pattern.Length])

    override this.Checksum = result

    override this.Prepare() =
        size <- int (this.ConfigVal("size"))
        testData <- generateTestData size
        result <- 0u

    override this.Run(_: int64) =
        let compressed = Compression.compress testData
        result <- result + uint32 compressed.EncodedBits.Length