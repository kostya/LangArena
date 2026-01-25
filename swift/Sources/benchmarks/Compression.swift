import Foundation

final class Compression: BenchmarkProtocol {
    private var iterations: Int = 0
    private var testData: [UInt8] = []
    
    init() {
        iterations = getIterations()
    }
    
    // ==================== BWT ====================
    private struct BWTResult {
        let transformed: [UInt8]
        let originalIdx: Int
        
        init(transformed: [UInt8], originalIdx: Int) {
            self.transformed = transformed
            self.originalIdx = originalIdx
        }
    }
    
    private func bwtTransform(_ input: [UInt8]) -> BWTResult {
        let n = input.count
        if n == 0 {
            return BWTResult(transformed: [], originalIdx: 0)
        }
        
        // 1. Создаём удвоенную строку
        var doubled = [UInt8](repeating: 0, count: n * 2)
        doubled[0..<n] = input[0..<n]
        doubled[n..<(2*n)] = input[0..<n]
        
        // 2. Создаём и сортируем суффиксный массив
        var sa = [Int](0..<n)
        
        // 3. Фаза 0: сортировка по первому символу (Radix sort)
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
        
        // 4. Фаза 1: сортировка по парам символов
        if n > 1 {
            // Присваиваем ранги по первому символу
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
            
            // Сортируем по парам (ранг[i], ранг[i+1])
            var k = 1
            while k < n {
                // Создаём пары
                var pairs = [(Int, Int)](repeating: (0, 0), count: n)
                for i in 0..<n {
                    pairs[i] = (rank[i], rank[(i + k) % n])
                }
                
                // Сортируем индексы по парам
                sa.sort { a, b in
                    let pairA = pairs[a]
                    let pairB = pairs[b]
                    if pairA.0 != pairB.0 {
                        return pairA.0 < pairB.0
                    } else {
                        return pairA.1 < pairB.1
                    }
                }
                
                // Обновляем ранги
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
        
        // 5. Собираем BWT результат
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
    
    private func bwtInverse(_ bwtResult: BWTResult) -> [UInt8] {
        let bwt = bwtResult.transformed
        let n = bwt.count
        if n == 0 {
            return []
        }
        
        // 1. Подсчитываем частоты символов
        var counts = [Int](repeating: 0, count: 256)
        for byte in bwt {
            counts[Int(byte)] += 1
        }
        
        // 2. Вычисляем стартовые позиции для каждого символа
        var positions = [Int](repeating: 0, count: 256)
        var total = 0
        for i in 0..<256 {
            positions[i] = total
            total += counts[i]
        }
        
        // 3. Строим массив next (LF-маппинг)
        var next = [Int](repeating: 0, count: n)
        var tempCounts = [Int](repeating: 0, count: 256)
        
        for (i, byte) in bwt.enumerated() {
            let byteIdx = Int(byte)
            let pos = positions[byteIdx] + tempCounts[byteIdx]
            next[pos] = i
            tempCounts[byteIdx] += 1
        }
        
        // 4. Восстанавливаем исходную строку
        var result = [UInt8](repeating: 0, count: n)
        var idx = bwtResult.originalIdx
        
        for i in 0..<n {
            idx = next[idx]
            result[i] = bwt[idx]
        }
        
        return result
    }
    
    // ==================== Huffman ====================
    private class HuffmanNode {
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
    
    private func buildHuffmanTree(_ frequencies: [Int]) -> HuffmanNode {
        var heap = [(HuffmanNode, Int)]() // (node, frequency)
        
        // Добавляем все символы с ненулевой частотой
        for (i, freq) in frequencies.enumerated() {
            if freq > 0 {
                heap.append((HuffmanNode(frequency: freq, byteVal: UInt8(i)), freq))
            }
        }
        
        // Сортируем по частоте (min-heap)
        heap.sort { $0.1 < $1.1 }
        
        // Если только один символ, создаём искусственный узел
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
        
        // Строим дерево
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
            
            // Вставляем родителя в правильную позицию (поддерживаем сортировку)
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
    
    private struct HuffmanCodes {
        var codeLengths = [Int](repeating: 0, count: 256)
        var codes = [Int](repeating: 0, count: 256)
    }
    
    private func buildHuffmanCodes(_ node: HuffmanNode, code: Int = 0, length: Int = 0, 
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
    
    private struct EncodedResult {
        let data: [UInt8]
        let bitCount: Int
    }
    
    private func huffmanEncode(_ data: [UInt8], _ huffmanCodes: HuffmanCodes) -> EncodedResult {
        // Предварительное выделение с запасом
        var result = [UInt8](repeating: 0, count: data.count * 2)
        var currentByte: UInt8 = 0
        var bitPos = 0
        var byteIndex = 0
        var totalBits = 0
        
        for byte in data {
            let idx = Int(byte)
            let code = huffmanCodes.codes[idx]
            let length = huffmanCodes.codeLengths[idx]
            
            // Копируем биты из code
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
        
        // Последний неполный байт
        if bitPos > 0 {
            result[byteIndex] = currentByte
            byteIndex += 1
        }
        
        return EncodedResult(data: Array(result[0..<byteIndex]), bitCount: totalBits)
    }
    
    private func huffmanDecode(_ encoded: [UInt8], _ root: HuffmanNode, _ bitCount: Int) -> [UInt8] {
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
    
    // ==================== Компрессор ====================
    private struct CompressedData {
        let bwtResult: BWTResult
        let frequencies: [Int]
        let encodedBits: [UInt8]
        let originalBitCount: Int
    }
    
    private func compress(_ data: [UInt8]) -> CompressedData {
        // 1. BWT преобразование
        let bwtResult = bwtTransform(data)
        
        // 2. Подсчёт частот
        var frequencies = [Int](repeating: 0, count: 256)
        for byte in bwtResult.transformed {
            frequencies[Int(byte)] += 1
        }
        
        // 3. Построение дерева Huffman
        let huffmanTree = buildHuffmanTree(frequencies)
        
        // 4. Построение кодов
        var huffmanCodes = HuffmanCodes()
        buildHuffmanCodes(huffmanTree, into: &huffmanCodes)
        
        // 5. Кодирование
        let encoded = huffmanEncode(bwtResult.transformed, huffmanCodes)
        
        return CompressedData(
            bwtResult: bwtResult,
            frequencies: frequencies,
            encodedBits: encoded.data,
            originalBitCount: encoded.bitCount
        )
    }
    
    private func decompress(_ compressed: CompressedData) -> [UInt8] {
        // 1. Восстанавливаем дерево Huffman
        let huffmanTree = buildHuffmanTree(compressed.frequencies)
        
        // 2. Декодирование Huffman
        let decoded = huffmanDecode(
            compressed.encodedBits,
            huffmanTree,
            compressed.originalBitCount
        )
        
        // 3. Обратное BWT
        let bwtResult = BWTResult(
            transformed: decoded,
            originalIdx: compressed.bwtResult.originalIdx
        )
        
        return bwtInverse(bwtResult)
    }
    
    // ==================== Benchmark ====================
    private func getIterations() -> Int {
        if let value = Helper.input["Compression"] {
            return Int(value) ?? 0
        }
        return 0
    }
    
    private func generateTestData(size: Int) -> [UInt8] {
        let pattern: [UInt8] = Array("ABRACADABRA".utf8)
        var data = [UInt8](repeating: 0, count: size)
        
        for i in 0..<size {
            data[i] = pattern[i % pattern.count]
        }
        
        return data
    }
    
    func prepare() {
        testData = generateTestData(size: iterations)
    }

    private var resultVal: Int64 = 0
    
    func run() {
        var totalChecksum: UInt32 = 0
        
        for _ in 0..<5 {
            // Компрессия
            let compressed = compress(testData)
            
            // Декомпрессия
            let decompressed = decompress(compressed)
            
            // Подсчёт checksum
            let checksum = Helper.checksum(decompressed)
            
            totalChecksum = totalChecksum &+ UInt32(compressed.encodedBits.count)
            totalChecksum = totalChecksum &+ checksum
        }
        
        resultVal = Int64(totalChecksum)
    }
    
    var result: Int64 {
        return Int64(resultVal)
    }
}