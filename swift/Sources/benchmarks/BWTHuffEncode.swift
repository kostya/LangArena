import Foundation

class BWTHuffEncode: BenchmarkProtocol {
    public struct BWTResult {
        let transformed: [UInt8]
        let originalIdx: Int

        init(transformed: [UInt8], originalIdx: Int) {
            self.transformed = transformed
            self.originalIdx = originalIdx
        }
    }

    public func bwtTransform(_ input: [UInt8]) -> BWTResult {
        let n = input.count
        if n == 0 {
            return BWTResult(transformed: [], originalIdx: 0)
        }

        var doubled = [UInt8](repeating: 0, count: n * 2)
        doubled[0..<n] = input[0..<n]
        doubled[n..<(2*n)] = input[0..<n]

        var sa = [Int](0..<n)

        var buckets = [[Int]](repeating: [], count: 256)
        for idx in sa {
            let firstChar = Int(input[idx])
            buckets[firstChar].append(idx)
        }

        var pos = 0
        for bucket in buckets {
            for idx in bucket {
                sa[pos] = idx
                pos += 1
            }
        }

        if n > 1 {
            var rank = [Int](repeating: 0, count: n)
            var currentRank = 0
            var prevChar = Int(input[sa[0]])

            for i in 0..<n {
                let idx = sa[i]
                let currChar = Int(input[idx])
                if currChar != prevChar {
                    currentRank += 1
                    prevChar = currChar
                }
                rank[idx] = currentRank
            }

            var k = 1
            while k < n {
                var pairs = [(Int, Int)](repeating: (0, 0), count: n)
                for i in 0..<n {
                    pairs[i] = (rank[i], rank[(i + k) % n])
                }

                sa.sort { a, b in
                    let pairA = pairs[a]
                    let pairB = pairs[b]
                    if pairA.0 != pairB.0 {
                        return pairA.0 < pairB.0
                    } else {
                        return pairA.1 < pairB.1
                    }
                }

                var newRank = [Int](repeating: 0, count: n)
                newRank[sa[0]] = 0
                for i in 1..<n {
                    let prevPair = pairs[sa[i - 1]]
                    let currPair = pairs[sa[i]]
                    newRank[sa[i]] = newRank[sa[i - 1]] + 
                        (prevPair != currPair ? 1 : 0)
                }

                rank = newRank
                k *= 2
            }
        }

        var transformed = [UInt8](repeating: 0, count: n)
        var originalIdx = 0

        for (i, suffix) in sa.enumerated() {
            if suffix == 0 {
                transformed[i] = input[n - 1]
                originalIdx = i
            } else {
                transformed[i] = input[suffix - 1]
            }
        }

        return BWTResult(transformed: transformed, originalIdx: originalIdx)
    }

    public func bwtInverse(_ bwtResult: BWTResult) -> [UInt8] {
        let bwt = bwtResult.transformed
        let n = bwt.count
        if n == 0 {
            return []
        }

        var counts = [Int](repeating: 0, count: 256)
        for byte in bwt {
            counts[Int(byte)] += 1
        }

        var positions = [Int](repeating: 0, count: 256)
        var total = 0
        for i in 0..<256 {
            positions[i] = total
            total += counts[i]
        }

        var next = [Int](repeating: 0, count: n)
        var tempCounts = [Int](repeating: 0, count: 256)

        for (i, byte) in bwt.enumerated() {
            let byteIdx = Int(byte)
            let pos = positions[byteIdx] + tempCounts[byteIdx]
            next[pos] = i
            tempCounts[byteIdx] += 1
        }

        var result = [UInt8](repeating: 0, count: n)
        var idx = bwtResult.originalIdx

        for i in 0..<n {
            idx = next[idx]
            result[i] = bwt[idx]
        }

        return result
    }

    public class HuffmanNode {
        let frequency: Int
        let byteVal: UInt8?
        let isLeaf: Bool
        let left: HuffmanNode?
        let right: HuffmanNode?

        init(frequency: Int, byteVal: UInt8? = nil, isLeaf: Bool = true, 
             left: HuffmanNode? = nil, right: HuffmanNode? = nil) {
            self.frequency = frequency
            self.byteVal = byteVal
            self.isLeaf = isLeaf
            self.left = left
            self.right = right
        }
    }

    public func buildHuffmanTree(_ frequencies: [Int]) -> HuffmanNode {
        var heap = [(HuffmanNode, Int)]()

        for (i, freq) in frequencies.enumerated() {
            if freq > 0 {
                heap.append((HuffmanNode(frequency: freq, byteVal: UInt8(i)), freq))
            }
        }

        heap.sort { $0.1 < $1.1 }

        if heap.count == 1 {
            let node = heap[0].0
            let root = HuffmanNode(
                frequency: node.frequency,
                byteVal: nil,
                isLeaf: false,
                left: node,
                right: HuffmanNode(frequency: 0, byteVal: 0)
            )
            return root
        }

        while heap.count > 1 {
            let (left, freq1) = heap.removeFirst()
            let (right, freq2) = heap.removeFirst()

            let parent = HuffmanNode(
                frequency: freq1 + freq2,
                byteVal: nil,
                isLeaf: false,
                left: left,
                right: right
            )

            let newFreq = freq1 + freq2
            var inserted = false
            for i in 0..<heap.count {
                if newFreq < heap[i].1 {
                    heap.insert((parent, newFreq), at: i)
                    inserted = true
                    break
                }
            }
            if !inserted {
                heap.append((parent, newFreq))
            }
        }

        return heap[0].0
    }

    public struct HuffmanCodes {
        var codeLengths = [Int](repeating: 0, count: 256)
        var codes = [Int](repeating: 0, count: 256)
    }

    public func buildHuffmanCodes(_ node: HuffmanNode, code: Int = 0, length: Int = 0, 
                                  into huffmanCodes: inout HuffmanCodes) {
        if node.isLeaf {
            if length > 0 || node.byteVal != 0 {
                let idx = Int(node.byteVal!)
                huffmanCodes.codeLengths[idx] = length
                huffmanCodes.codes[idx] = code
            }
        } else {
            if let left = node.left {
                buildHuffmanCodes(left, code: code << 1, length: length + 1, into: &huffmanCodes)
            }
            if let right = node.right {
                buildHuffmanCodes(right, code: (code << 1) | 1, length: length + 1, into: &huffmanCodes)
            }
        }
    }

    public struct EncodedResult {
        let data: [UInt8]
        let bitCount: Int
    }

    public func huffmanEncode(_ data: [UInt8], _ huffmanCodes: HuffmanCodes) -> EncodedResult {
        var result = [UInt8](repeating: 0, count: data.count * 2)
        var currentByte: UInt8 = 0
        var bitPos = 0
        var byteIndex = 0
        var totalBits = 0

        for byte in data {
            let idx = Int(byte)
            let code = huffmanCodes.codes[idx]
            let length = huffmanCodes.codeLengths[idx]

            for i in stride(from: length - 1, through: 0, by: -1) {
                if (code & (1 << i)) != 0 {
                    currentByte |= 1 << (7 - bitPos)
                }
                bitPos += 1
                totalBits += 1

                if bitPos == 8 {
                    result[byteIndex] = currentByte
                    byteIndex += 1
                    currentByte = 0
                    bitPos = 0
                }
            }
        }

        if bitPos > 0 {
            result[byteIndex] = currentByte
            byteIndex += 1
        }

        return EncodedResult(data: Array(result[0..<byteIndex]), bitCount: totalBits)
    }

    public func huffmanDecode(_ encoded: [UInt8], _ root: HuffmanNode, _ bitCount: Int) -> [UInt8] {
        var result = [UInt8]()
        result.reserveCapacity(bitCount / 4 + 1)

        var currentNode = root
        var bitsProcessed = 0
        var byteIndex = 0

        while bitsProcessed < bitCount && byteIndex < encoded.count {
            let byteVal = encoded[byteIndex]
            byteIndex += 1

            for bitPos in stride(from: 7, through: 0, by: -1) {
                if bitsProcessed >= bitCount {
                    break
                }

                let bit = ((byteVal >> bitPos) & 1) == 1
                bitsProcessed += 1

                currentNode = bit ? currentNode.right! : currentNode.left!

                if currentNode.isLeaf {
                    if currentNode.byteVal != 0 {
                        result.append(currentNode.byteVal!)
                    }
                    currentNode = root
                }
            }
        }

        return result
    }

    public struct CompressedData {
        let bwtResult: BWTResult
        let frequencies: [Int]
        let encodedBits: [UInt8]
        let originalBitCount: Int
    }

    public func compress(_ data: [UInt8]) -> CompressedData {
        let bwtResult = bwtTransform(data)

        var frequencies = [Int](repeating: 0, count: 256)
        for byte in bwtResult.transformed {
            frequencies[Int(byte)] += 1
        }

        let huffmanTree = buildHuffmanTree(frequencies)

        var huffmanCodes = HuffmanCodes()
        buildHuffmanCodes(huffmanTree, into: &huffmanCodes)

        let encoded = huffmanEncode(bwtResult.transformed, huffmanCodes)

        return CompressedData(
            bwtResult: bwtResult,
            frequencies: frequencies,
            encodedBits: encoded.data,
            originalBitCount: encoded.bitCount
        )
    }

    public func decompress(_ compressed: CompressedData) -> [UInt8] {
        let huffmanTree = buildHuffmanTree(compressed.frequencies)

        let decoded = huffmanDecode(
            compressed.encodedBits,
            huffmanTree,
            compressed.originalBitCount
        )

        let bwtResult = BWTResult(
            transformed: decoded,
            originalIdx: compressed.bwtResult.originalIdx
        )

        return bwtInverse(bwtResult)
    }

    public func generateTestData(_ dataSize: Int64) -> [UInt8] {
        let pattern: [UInt8] = Array("ABRACADABRA".utf8)
        var data = [UInt8](repeating: 0, count: Int(dataSize))

        for i in 0..<Int(dataSize) {
            data[i] = pattern[i % pattern.count]
        }

        return data
    }

    public var sizeVal: Int64 = 0
    public var testData: [UInt8] = []
    public var resultVal: UInt32 = 0

    init() {
        sizeVal = configValue("size") ?? 0
    }

    func prepare() {
        testData = generateTestData(sizeVal)
    }

    func run(iterationId: Int) {
        let compressed = compress(testData)
        resultVal &+= UInt32(compressed.encodedBits.count)
    }

    var checksum: UInt32 {
        return resultVal
    }
}