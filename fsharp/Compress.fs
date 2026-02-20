namespace Benchmarks

open System
open System.Collections.Generic

module CompressHelpers =
    let generateTestData (size: int64) : byte[] =
        let pattern = "ABRACADABRA"B
        Array.init (int size) (fun i -> pattern.[i % pattern.Length])

[<Struct>]
type BWTResult = 
    { 
        Transformed: byte[]
        OriginalIdx: int 
    }

type BWTEncode =
    inherit Benchmark

    val mutable sizeVal: int64
    val mutable testData: byte[]
    val mutable bwtResult: BWTResult
    val mutable resultVal: uint32

    member this.TestData = this.testData
    member this.BwtResult = this.bwtResult

    new() = 
        { 
            inherit Benchmark()
            sizeVal = Helper.Config_i64("Compress::BWTEncode", "size")
            testData = Array.empty<byte>
            bwtResult = { Transformed = Array.empty<byte>; OriginalIdx = 0 }
            resultVal = uint32 0
        }

    member private this.BwtTransform(input: byte[]) : BWTResult =
        let n = input.Length
        if n = 0 then { Transformed = [||]; OriginalIdx = 0 }
        else
            let sa = Array.init n id

            let buckets = Array.init 256 (fun _ -> List<int>())
            for i = 0 to n - 1 do
                buckets.[int input.[i]].Add(i)

            let mutable pos = 0
            for bucket in buckets do
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

    override this.Name = "Compress::BWTEncode"

    override this.Prepare() =
        this.testData <- CompressHelpers.generateTestData this.sizeVal
        this.resultVal <- 0u

    override this.Run(iterationId: int64) =
        this.bwtResult <- this.BwtTransform(this.testData)
        this.resultVal <- this.resultVal + uint32 this.bwtResult.Transformed.Length

    override this.Checksum = this.resultVal

type BWTDecode() =
    inherit Benchmark()

    let mutable sizeVal = 0L
    let mutable testData = Array.empty<byte>
    let mutable inverted = Array.empty<byte>
    let mutable bwtResult = { Transformed = Array.empty; OriginalIdx = 0 }
    let mutable resultVal = 0u

    member private this.BwtInverse(bwtResult: BWTResult) : byte[] =
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
            let tempCounts = Array.zeroCreate<int> 256

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

    override this.Name = "Compress::BWTDecode"

    override this.Prepare() =
        sizeVal <- this.ConfigVal("size")
        let encoder = BWTEncode()
        encoder.sizeVal <- sizeVal
        encoder.Prepare()
        encoder.Run(0)
        testData <- encoder.TestData
        bwtResult <- encoder.BwtResult
        resultVal <- 0u

    override this.Run(iterationId: int64) =
        inverted <- this.BwtInverse(bwtResult)
        resultVal <- resultVal + uint32 inverted.Length

    override this.Checksum =
        let mutable res = resultVal
        if inverted <> null && testData <> null && inverted.Length = testData.Length then
            let mutable equal = true
            for i = 0 to inverted.Length - 1 do
                if inverted.[i] <> testData.[i] then equal <- false
            if equal then res <- res + 100000u
        res

module Huffman =
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

    type HuffmanCodes() =
        let codeLengths = Array.zeroCreate<int> 256
        let codes = Array.zeroCreate<int> 256

        member _.CodeLengths = codeLengths
        member _.Codes = codes

    type EncodedResult = 
        { 
            Data: byte[]
            BitCount: int
            Frequencies: int[]
        }

    let rec buildHuffmanTree (frequencies: int[]) : HuffmanNode =
        let nodes = List<HuffmanNode>()

        for i = 0 to frequencies.Length - 1 do
            if frequencies.[i] > 0 then
                nodes.Add(HuffmanNode(frequencies.[i], byte i))

        let sorted = nodes |> Seq.sortBy (fun n -> n.Frequency) |> Seq.toList
        let mutable nodesList = sorted

        if nodesList.Length = 1 then
            let node = nodesList.[0]
            let root = HuffmanNode(node.Frequency, 0uy, false, node, HuffmanNode(0, 0uy))
            root
        else
            while nodesList.Length > 1 do
                let left = nodesList.[0]
                let right = nodesList.[1]
                nodesList <- nodesList.[2..]

                let parent = HuffmanNode(left.Frequency + right.Frequency, 0uy, false, left, right)

                let pos = nodesList |> List.tryFindIndex (fun n -> n.Frequency >= parent.Frequency)
                match pos with
                | Some p -> nodesList <- nodesList.[0..p-1] @ [parent] @ nodesList.[p..]
                | None -> nodesList <- nodesList @ [parent]

            nodesList.[0]

    let rec buildHuffmanCodes (node: HuffmanNode) (code: int) (length: int) (codes: HuffmanCodes) =
        if node.IsLeaf then
            if length > 0 || node.ByteVal <> 0uy then
                let idx = int node.ByteVal
                codes.CodeLengths.[idx] <- length
                codes.Codes.[idx] <- code
        else
            if node.Left <> Unchecked.defaultof<HuffmanNode> then
                buildHuffmanCodes node.Left (code <<< 1) (length + 1) codes
            if node.Right <> Unchecked.defaultof<HuffmanNode> then
                buildHuffmanCodes node.Right ((code <<< 1) ||| 1) (length + 1) codes

    let huffmanEncode (data: byte[]) (codes: HuffmanCodes) (frequencies: int[]) : EncodedResult =

        let result = ResizeArray<byte>(data.Length * 2)  
        let mutable currentByte = 0uy
        let mutable bitPos = 0
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
                    result.Add(currentByte)  
                    currentByte <- 0uy
                    bitPos <- 0

        if bitPos > 0 then
            result.Add(currentByte)  

        { 
            Data = result.ToArray()
            BitCount = totalBits
            Frequencies = frequencies
        }

    let huffmanDecode (encoded: byte[]) (root: HuffmanNode) (bitCount: int) : byte[] =
        let result = Array.zeroCreate<byte> bitCount
        let mutable resultSize = 0

        let mutable currentNode = root
        let mutable bitsProcessed = 0
        let mutable byteIndex = 0

        while bitsProcessed < bitCount && byteIndex < encoded.Length do
            let byteVal = encoded.[byteIndex]
            byteIndex <- byteIndex + 1

            let mutable bitPos = 7
            while bitPos >= 0 && bitsProcessed < bitCount do
                let bit = (byteVal >>> bitPos) &&& 1uy
                bitsProcessed <- bitsProcessed + 1

                currentNode <- if bit = 1uy then currentNode.Right else currentNode.Left

                if currentNode.IsLeaf then

                    result.[resultSize] <- currentNode.ByteVal
                    resultSize <- resultSize + 1
                    currentNode <- root

                bitPos <- bitPos - 1

        if resultSize = bitCount then 
            result 
        else 
            Array.sub result 0 resultSize

type HuffEncode =
    inherit Benchmark

    val mutable sizeVal: int64
    val mutable testData: byte[]
    val mutable encodedResult: Huffman.EncodedResult
    val mutable resultVal: uint32

    member this.Encoded = this.encodedResult
    member this.TestData = this.testData

    new() = 
        { 
            inherit Benchmark()
            sizeVal = Helper.Config_i64("Compress::HuffEncode", "size")
            testData = Array.empty<byte>
            encodedResult = Unchecked.defaultof<Huffman.EncodedResult>
            resultVal = uint32 0
        }

    override this.Name = "Compress::HuffEncode"

    override this.Prepare() =
        this.testData <- CompressHelpers.generateTestData this.sizeVal
        this.resultVal <- 0u

    override this.Run(iterationId: int64) =
        let frequencies = Array.zeroCreate<int> 256
        for b in this.testData do
            frequencies.[int b] <- frequencies.[int b] + 1

        let tree = Huffman.buildHuffmanTree frequencies

        let codes = Huffman.HuffmanCodes()
        Huffman.buildHuffmanCodes tree 0 0 codes

        this.encodedResult <- Huffman.huffmanEncode this.testData codes frequencies
        this.resultVal <- this.resultVal + uint32 this.encodedResult.Data.Length

    override this.Checksum = this.resultVal

type HuffDecode() =
    inherit Benchmark()

    let mutable sizeVal = 0L
    let mutable testData = Array.empty<byte>
    let mutable decoded = Array.empty<byte>
    let mutable encodedResult = Unchecked.defaultof<Huffman.EncodedResult>
    let mutable resultVal = 0u

    override this.Name = "Compress::HuffDecode"

    override this.Prepare() =
        sizeVal <- this.ConfigVal("size")
        testData <- CompressHelpers.generateTestData sizeVal

        let encoder = HuffEncode()
        encoder.sizeVal <- sizeVal
        encoder.Prepare()
        encoder.Run(0L)
        encodedResult <- encoder.Encoded
        resultVal <- 0u

    override this.Run(iterationId: int64) =
        let tree = Huffman.buildHuffmanTree encodedResult.Frequencies
        decoded <- Huffman.huffmanDecode encodedResult.Data tree encodedResult.BitCount
        resultVal <- resultVal + uint32 decoded.Length

    override this.Checksum =
        let mutable res = resultVal
        if decoded <> null && testData <> null && decoded.Length = testData.Length then
            let mutable equal = true
            for i = 0 to decoded.Length - 1 do
                if decoded.[i] <> testData.[i] then equal <- false
            if equal then res <- res + 100000u
        res

type ArithFreqTable(frequencies: int[]) =
    let mutable total = 0
    let low = Array.zeroCreate<int> 256
    let high = Array.zeroCreate<int> 256

    do
        for f in frequencies do total <- total + f

        let mutable cum = 0
        for i = 0 to 255 do
            low.[i] <- cum
            cum <- cum + frequencies.[i]
            high.[i] <- cum

    member _.Total = total
    member _.Low = low
    member _.High = high

type BitOutputStream() =
    let mutable buffer = 0
    let mutable bitPos = 0
    let mutable bytes = List<byte>()
    let mutable bitsWritten = 0

    member _.WriteBit(bit: int) =
        buffer <- (buffer <<< 1) ||| (bit &&& 1)
        bitPos <- bitPos + 1
        bitsWritten <- bitsWritten + 1

        if bitPos = 8 then
            bytes.Add(byte buffer)
            buffer <- 0
            bitPos <- 0

    member _.Flush() : byte[] =
        if bitPos > 0 then
            buffer <- buffer <<< (8 - bitPos)
            bytes.Add(byte buffer)
        bytes.ToArray()

    member _.BitsWritten = bitsWritten

type ArithEncodedResult = 
    { 
        Data: byte[]
        BitCount: int
        Frequencies: int[]
    }

type ArithEncode =
    inherit Benchmark

    val mutable sizeVal: int64
    val mutable testData: byte[]
    val mutable encoded: ArithEncodedResult
    val mutable resultVal: uint32

    member this.TestData = this.testData
    member this.Encoded = this.encoded

    new() = 
        { 
            inherit Benchmark()
            sizeVal = Helper.Config_i64("Compress::ArithEncode", "size")
            testData = Array.empty<byte>
            encoded = { Data = Array.empty<byte>; BitCount = 0; Frequencies = Array.empty<int> }
            resultVal = uint32 0
        }

    member private this.ArithEncode(data: byte[]) : ArithEncodedResult =
        let frequencies = Array.zeroCreate<int> 256
        for b in data do frequencies.[int b] <- frequencies.[int b] + 1

        let freqTable = ArithFreqTable(frequencies)

        let mutable low = 0UL
        let mutable high = 0xFFFFFFFFUL
        let mutable pending = 0
        let output = BitOutputStream()

        for b in data do
            let idx = int b
            let range = high - low + 1UL

            high <- low + (range * uint64 freqTable.High.[idx] / uint64 freqTable.Total) - 1UL
            low <- low + (range * uint64 freqTable.Low.[idx] / uint64 freqTable.Total)

            let mutable cont = true
            while cont do
                if high < 0x80000000UL then
                    output.WriteBit(0)
                    for i = 0 to pending - 1 do output.WriteBit(1)
                    pending <- 0
                elif low >= 0x80000000UL then
                    output.WriteBit(1)
                    for i = 0 to pending - 1 do output.WriteBit(0)
                    pending <- 0
                    low <- low - 0x80000000UL
                    high <- high - 0x80000000UL
                elif low >= 0x40000000UL && high < 0xC0000000UL then
                    pending <- pending + 1
                    low <- low - 0x40000000UL
                    high <- high - 0x40000000UL
                else
                    cont <- false

                if not cont then () else
                low <- low <<< 1
                high <- (high <<< 1) ||| 1UL
                high <- high &&& 0xFFFFFFFFUL

        pending <- pending + 1
        if low < 0x40000000UL then
            output.WriteBit(0)
            for i = 0 to pending - 1 do output.WriteBit(1)
        else
            output.WriteBit(1)
            for i = 0 to pending - 1 do output.WriteBit(0)

        { 
            Data = output.Flush()
            BitCount = output.BitsWritten
            Frequencies = frequencies
        }

    override this.Name = "Compress::ArithEncode"

    override this.Prepare() =
        this.testData <- CompressHelpers.generateTestData this.sizeVal
        this.resultVal <- 0u

    override this.Run(iterationId: int64) =
        this.encoded <- this.ArithEncode(this.testData)
        this.resultVal <- this.resultVal + uint32 this.encoded.Data.Length

    override this.Checksum = this.resultVal

type BitInputStream(bytes: byte[]) =
    let mutable bytePos = 0
    let mutable bitPos = 0
    let mutable currentByte = if bytes.Length > 0 then bytes.[0] else 0uy

    member _.ReadBit() : int =
        if bitPos = 8 then
            bytePos <- bytePos + 1
            bitPos <- 0
            currentByte <- if bytePos < bytes.Length then bytes.[bytePos] else 0uy

        let bit = int ((currentByte >>> (7 - bitPos)) &&& 1uy)
        bitPos <- bitPos + 1
        bit

type ArithDecode() =
    inherit Benchmark()

    let mutable sizeVal = 0L
    let mutable testData = Array.empty<byte>
    let mutable decoded = Array.empty<byte>
    let mutable encoded = { Data = Array.empty; BitCount = 0; Frequencies = Array.empty }
    let mutable resultVal = 0u

    member private this.ArithDecode(encoded: ArithEncodedResult) : byte[] =
        let frequencies = encoded.Frequencies
        let total = frequencies |> Array.sum
        let dataSize = total

        let lowTable = Array.zeroCreate<int> 256
        let highTable = Array.zeroCreate<int> 256
        let mutable cum = 0
        for i = 0 to 255 do
            lowTable.[i] <- cum
            cum <- cum + frequencies.[i]
            highTable.[i] <- cum

        let result = Array.zeroCreate<byte> dataSize
        let input = BitInputStream(encoded.Data)

        let mutable value = 0UL
        for i = 0 to 31 do
            value <- (value <<< 1) ||| uint64 (input.ReadBit())

        let mutable low = 0UL
        let mutable high = 0xFFFFFFFFUL

        for j = 0 to dataSize - 1 do
            let range = high - low + 1UL
            let scaled = ((value - low + 1UL) * uint64 total - 1UL) / range

            let mutable symbol = 0
            while symbol < 255 && uint64 highTable.[symbol] <= scaled do
                symbol <- symbol + 1

            result.[j] <- byte symbol

            high <- low + (range * uint64 highTable.[symbol] / uint64 total) - 1UL
            low <- low + (range * uint64 lowTable.[symbol] / uint64 total)

            let mutable cont = true
            while cont do
                if high < 0x80000000UL then

                    ()
                elif low >= 0x80000000UL then
                    value <- value - 0x80000000UL
                    low <- low - 0x80000000UL
                    high <- high - 0x80000000UL
                elif low >= 0x40000000UL && high < 0xC0000000UL then
                    value <- value - 0x40000000UL
                    low <- low - 0x40000000UL
                    high <- high - 0x40000000UL
                else
                    cont <- false

                if cont then
                    low <- low <<< 1
                    high <- (high <<< 1) ||| 1UL
                    value <- (value <<< 1) ||| uint64 (input.ReadBit())

        result

    override this.Name = "Compress::ArithDecode"

    override this.Prepare() =
        sizeVal <- this.ConfigVal("size")
        let encoder = ArithEncode()
        encoder.sizeVal <- sizeVal
        encoder.Prepare()
        encoder.Run(0)
        testData <- encoder.TestData
        encoded <- encoder.Encoded
        resultVal <- 0u

    override this.Run(iterationId: int64) =
        decoded <- this.ArithDecode(encoded)
        resultVal <- resultVal + uint32 decoded.Length

    override this.Checksum =
        let mutable res = resultVal
        if decoded <> null && testData <> null && decoded.Length = testData.Length then
            let mutable equal = true
            for i = 0 to decoded.Length - 1 do
                if decoded.[i] <> testData.[i] then equal <- false
            if equal then res <- res + 100000u
        res

type LZWResult = 
    { 
        Data: byte[]
        DictSize: int 
    }

type LZWEncode =
    inherit Benchmark

    val mutable sizeVal: int64
    val mutable testData: byte[]
    val mutable encoded: LZWResult
    val mutable resultVal: uint32

    member this.TestData = this.testData
    member this.Encoded = this.encoded

    new() = 
        { 
            inherit Benchmark()
            sizeVal = Helper.Config_i64("Compress::LZWEncode", "size")
            testData = Array.empty<byte>
            encoded = { Data = Array.empty<byte>; DictSize = 256 }
            resultVal = uint32 0
        }

    member private this.LzwEncode(input: byte[]) : LZWResult =
        if input.Length = 0 then { Data = [||]; DictSize = 256 }
        else

            let dict = Dictionary<string, int>(4096)
            for i = 0 to 255 do
                dict.[string(byte i)] <- i

            let mutable nextCode = 256

            let result = ResizeArray<byte>(input.Length * 2)

            let mutable current = string input.[0]

            for i = 1 to input.Length - 1 do
                let nextChar = string input.[i]
                let newStr = current + nextChar

                if dict.ContainsKey(newStr) then
                    current <- newStr
                else
                    let code = dict.[current]
                    result.Add(byte ((code >>> 8) &&& 0xFF))
                    result.Add(byte (code &&& 0xFF))

                    dict.[newStr] <- nextCode
                    nextCode <- nextCode + 1
                    current <- nextChar

            let code = dict.[current]
            result.Add(byte ((code >>> 8) &&& 0xFF))
            result.Add(byte (code &&& 0xFF))

            { Data = result.ToArray(); DictSize = nextCode }

    override this.Name = "Compress::LZWEncode"

    override this.Prepare() =
        this.testData <- CompressHelpers.generateTestData this.sizeVal
        this.resultVal <- 0u

    override this.Run(iterationId: int64) =
        this.encoded <- this.LzwEncode(this.testData)
        this.resultVal <- this.resultVal + uint32 this.encoded.Data.Length

    override this.Checksum = this.resultVal

type LZWDecode() =
    inherit Benchmark()

    let mutable sizeVal = 0L
    let mutable testData = Array.empty<byte>
    let mutable decoded = Array.empty<byte>
    let mutable encoded = { Data = Array.empty; DictSize = 256 }
    let mutable resultVal = 0u

    member private this.LzwDecode(encoded: LZWResult) : byte[] =
        if encoded.Data.Length = 0 then [||]
        else
            let dict = List<string>()
            for i = 0 to 255 do
                dict.Add(string(byte i))

            let result = List<byte>()
            let data = encoded.Data
            let mutable pos = 0

            let high = int data.[pos]
            let low = int data.[pos + 1]
            let mutable oldCode = (high <<< 8) ||| low
            pos <- pos + 2

            let mutable oldStr = dict.[oldCode]
            for c in oldStr.ToCharArray() do
                result.Add(byte c)

            let mutable nextCode = 256

            while pos < data.Length do
                let high = int data.[pos]
                let low = int data.[pos + 1]
                let newCode = (high <<< 8) ||| low
                pos <- pos + 2

                let newStr = 
                    if newCode < dict.Count then
                        dict.[newCode]
                    elif newCode = nextCode then
                        oldStr + string (oldStr.[0])  
                    else
                        failwith "Error decode"

                for c in newStr.ToCharArray() do
                    result.Add(byte c)

                dict.Add(oldStr + string (newStr.[0]))
                nextCode <- nextCode + 1
                oldCode <- newCode  
                oldStr <- newStr     

            result.ToArray()

    override this.Name = "Compress::LZWDecode"

    override this.Prepare() =
        sizeVal <- this.ConfigVal("size")
        let encoder = LZWEncode()
        encoder.sizeVal <- sizeVal
        encoder.Prepare()
        encoder.Run(0)
        testData <- encoder.TestData
        encoded <- encoder.Encoded
        resultVal <- 0u

    override this.Run(iterationId: int64) =
        decoded <- this.LzwDecode(encoded)
        resultVal <- resultVal + uint32 decoded.Length

    override this.Checksum =
        let mutable res = resultVal
        if decoded <> null && testData <> null && decoded.Length = testData.Length then
            let mutable equal = true
            for i = 0 to decoded.Length - 1 do
                if decoded.[i] <> testData.[i] then equal <- false
            if equal then res <- res + 100000u
        res