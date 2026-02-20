import Foundation

func generateTestData(_ dataSize: Int64) -> [UInt8] {
  let pattern: [UInt8] = Array("ABRACADABRA".utf8)
  var data = [UInt8](repeating: 0, count: Int(dataSize))

  for i in 0..<Int(dataSize) {
    data[i] = pattern[i % pattern.count]
  }

  return data
}

class BWTEncode: BenchmarkProtocol {
  struct BWTResult {
    let transformed: [UInt8]
    let originalIdx: Int

    init(transformed: [UInt8], originalIdx: Int) {
      self.transformed = transformed
      self.originalIdx = originalIdx
    }
  }

  var sizeVal: Int64 = 0
  var testData: [UInt8] = []
  var bwtResult: BWTResult?
  var resultVal: UInt32 = 0

  required init() {
    sizeVal = configValue("size") ?? 0
  }

  func name() -> String {
    return "Compress::BWTEncode"
  }

  func prepare() {
    testData = generateTestData(sizeVal)
    resultVal = 0
  }

  func run(iterationId: Int) {
    bwtResult = bwtTransform(testData)
    resultVal &+= UInt32(bwtResult!.transformed.count)
  }

  var checksum: UInt32 {
    return resultVal
  }

  func bwtTransform(_ input: [UInt8]) -> BWTResult {
    let n = input.count
    if n == 0 {
      return BWTResult(transformed: [], originalIdx: 0)
    }

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
          newRank[sa[i]] = newRank[sa[i - 1]] + (prevPair != currPair ? 1 : 0)
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
}

class BWTDecode: BenchmarkProtocol {
  var sizeVal: Int64 = 0
  var testData: [UInt8] = []
  var inverted: [UInt8] = []
  var bwtResult: BWTEncode.BWTResult?
  var resultVal: UInt32 = 0

  required init() {
    sizeVal = configValue("size") ?? 0
  }

  func name() -> String {
    return "Compress::BWTDecode"
  }

  func prepare() {
    testData = generateTestData(sizeVal)

    let encoder = BWTEncode()
    encoder.sizeVal = sizeVal
    encoder.prepare()
    encoder.run(iterationId: 0)
    bwtResult = encoder.bwtResult
    resultVal = 0
  }

  func run(iterationId: Int) {
    inverted = bwtInverse(bwtResult!)
    resultVal &+= UInt32(inverted.count)
  }

  var checksum: UInt32 {
    var res = resultVal
    if inverted == testData {
      res &+= 100000
    }
    return res
  }

  func bwtInverse(_ bwtResult: BWTEncode.BWTResult) -> [UInt8] {
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
}

class HuffmanNode {
  let frequency: Int
  let byteVal: UInt8
  let isLeaf: Bool
  let left: HuffmanNode?
  let right: HuffmanNode?

  init(
    frequency: Int,
    byteVal: UInt8 = 0,
    isLeaf: Bool = true,
    left: HuffmanNode? = nil,
    right: HuffmanNode? = nil
  ) {
    self.frequency = frequency
    self.byteVal = byteVal
    self.isLeaf = isLeaf
    self.left = left
    self.right = right
  }
}

struct HuffmanCodes {
  var codeLengths = [Int](repeating: 0, count: 256)
  var codes = [Int](repeating: 0, count: 256)
}

struct EncodedResult {
  let data: [UInt8]
  let bitCount: Int
  let frequencies: [Int]
}

class HuffEncode: BenchmarkProtocol {
  var sizeVal: Int64 = 0
  var testData: [UInt8] = []
  var encoded: EncodedResult?
  var resultVal: UInt32 = 0

  required init() {
    sizeVal = configValue("size") ?? 0
  }

  func name() -> String {
    return "Compress::HuffEncode"
  }

  func prepare() {
    testData = generateTestData(sizeVal)
    resultVal = 0
  }

  func run(iterationId: Int) {
    var frequencies = [Int](repeating: 0, count: 256)
    for byte in testData {
      frequencies[Int(byte)] += 1
    }

    let tree = HuffEncode.buildHuffmanTree(frequencies)

    var codes = HuffmanCodes()
    buildHuffmanCodes(tree, code: 0, length: 0, into: &codes)

    encoded = huffmanEncode(testData, codes, frequencies: frequencies)
    resultVal &+= UInt32(encoded!.data.count)
  }

  var checksum: UInt32 {
    return resultVal
  }

  static func buildHuffmanTree(_ frequencies: [Int]) -> HuffmanNode {
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
        byteVal: 0,
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
        byteVal: 0,
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

  func buildHuffmanCodes(
    _ node: HuffmanNode, code: Int, length: Int, into huffmanCodes: inout HuffmanCodes
  ) {
    if node.isLeaf {
      if length > 0 || node.byteVal != 0 {
        let idx = Int(node.byteVal)
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

  func huffmanEncode(_ data: [UInt8], _ huffmanCodes: HuffmanCodes, frequencies: [Int])
    -> EncodedResult
  {

    var result = [UInt8]()

    result.reserveCapacity(data.count * 2)

    var currentByte: UInt8 = 0
    var bitPos = 0
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
          result.append(currentByte)
          currentByte = 0
          bitPos = 0
        }
      }
    }

    if bitPos > 0 {
      result.append(currentByte)
    }

    return EncodedResult(
      data: result,
      bitCount: totalBits,
      frequencies: frequencies
    )
  }
}

class HuffDecode: BenchmarkProtocol {
  var sizeVal: Int64 = 0
  var testData: [UInt8] = []
  var decoded: [UInt8] = []
  var encoded: EncodedResult?
  var resultVal: UInt32 = 0

  required init() {
    sizeVal = configValue("size") ?? 0
  }

  func name() -> String {
    return "Compress::HuffDecode"
  }

  func prepare() {
    testData = generateTestData(sizeVal)

    let encoder = HuffEncode()
    encoder.sizeVal = sizeVal
    encoder.prepare()
    encoder.run(iterationId: 0)
    encoded = encoder.encoded
    resultVal = 0
  }

  func run(iterationId: Int) {
    let tree = HuffEncode.buildHuffmanTree(encoded!.frequencies)
    decoded = huffmanDecode(encoded!.data, tree, encoded!.bitCount)
    resultVal &+= UInt32(decoded.count)
  }

  var checksum: UInt32 {
    var res = resultVal
    if decoded == testData {
      res &+= 100000
    }
    return res
  }

  func huffmanDecode(_ encoded: [UInt8], _ root: HuffmanNode, _ bitCount: Int) -> [UInt8] {
    var result = [UInt8]()

    var currentNode = root
    var bitsProcessed = 0
    var byteIndex = 0

    while bitsProcessed < bitCount && byteIndex < encoded.count {
      let byteVal = encoded[byteIndex]
      byteIndex += 1

      var bitPos = 7
      while bitPos >= 0 && bitsProcessed < bitCount {
        let bit = ((byteVal >> bitPos) & 1) == 1
        bitsProcessed += 1

        currentNode = bit ? currentNode.right! : currentNode.left!

        if currentNode.isLeaf {
          result.append(currentNode.byteVal)

          currentNode = root
        }
        bitPos -= 1
      }
    }

    return result
  }
}

class ArithFreqTable {
  let total: Int
  let low: [Int]
  let high: [Int]

  init(_ frequencies: [Int]) {
    total = frequencies.reduce(0, +)

    var lowTable = [Int](repeating: 0, count: 256)
    var highTable = [Int](repeating: 0, count: 256)

    var cum = 0
    for i in 0..<256 {
      lowTable[i] = cum
      cum += frequencies[i]
      highTable[i] = cum
    }

    self.low = lowTable
    self.high = highTable
  }
}

class BitOutputStream {
  private var buffer: Int = 0
  private var bitPos: Int = 0
  private var bytes: [UInt8] = []
  private var bitsWritten: Int = 0

  func writeBit(_ bit: Int) {
    buffer = (buffer << 1) | (bit & 1)
    bitPos += 1
    bitsWritten += 1

    if bitPos == 8 {
      bytes.append(UInt8(buffer & 0xFF))
      buffer = 0
      bitPos = 0
    }
  }

  func writeBits(_ bits: Int, count: Int) {
    for i in stride(from: count - 1, through: 0, by: -1) {
      writeBit((bits >> i) & 1)
    }
  }

  func flush() -> [UInt8] {
    if bitPos > 0 {
      buffer <<= (8 - bitPos)
      bytes.append(UInt8(buffer & 0xFF))
    }
    return bytes
  }

  var bitsWrittenCount: Int {
    return bitsWritten
  }
}

struct ArithEncodedResult {
  let data: [UInt8]
  let bitCount: Int
  let frequencies: [Int]
}

class ArithEncode: BenchmarkProtocol {
  var sizeVal: Int64 = 0
  var testData: [UInt8] = []
  var encoded: ArithEncodedResult?
  var resultVal: UInt32 = 0

  required init() {
    sizeVal = configValue("size") ?? 0
  }

  func name() -> String {
    return "Compress::ArithEncode"
  }

  func prepare() {
    testData = generateTestData(sizeVal)
    resultVal = 0
  }

  func run(iterationId: Int) {
    encoded = arithEncode(testData)
    resultVal &+= UInt32(encoded!.data.count)
  }

  var checksum: UInt32 {
    return resultVal
  }

  func arithEncode(_ data: [UInt8]) -> ArithEncodedResult {
    var frequencies = [Int](repeating: 0, count: 256)
    for byte in data {
      frequencies[Int(byte)] += 1
    }

    let freqTable = ArithFreqTable(frequencies)

    var low: UInt64 = 0
    var high: UInt64 = 0xFFFF_FFFF
    var pending = 0
    let output = BitOutputStream()

    for byte in data {
      let idx = Int(byte)
      let range = high - low + 1

      high = low + (range * UInt64(freqTable.high[idx]) / UInt64(freqTable.total)) - 1
      low = low + (range * UInt64(freqTable.low[idx]) / UInt64(freqTable.total))

      while true {
        if high < 0x8000_0000 {
          output.writeBit(0)
          for _ in 0..<pending {
            output.writeBit(1)
          }
          pending = 0
        } else if low >= 0x8000_0000 {
          output.writeBit(1)
          for _ in 0..<pending {
            output.writeBit(0)
          }
          pending = 0
          low -= 0x8000_0000
          high -= 0x8000_0000
        } else if low >= 0x4000_0000 && high < 0xC000_0000 {
          pending += 1
          low -= 0x4000_0000
          high -= 0x4000_0000
        } else {
          break
        }

        low <<= 1
        high = (high << 1) | 1
        high &= 0xFFFF_FFFF
      }
    }

    pending += 1
    if low < 0x4000_0000 {
      output.writeBit(0)
      for _ in 0..<pending {
        output.writeBit(1)
      }
    } else {
      output.writeBit(1)
      for _ in 0..<pending {
        output.writeBit(0)
      }
    }

    return ArithEncodedResult(
      data: output.flush(),
      bitCount: output.bitsWrittenCount,
      frequencies: frequencies
    )
  }
}

class BitInputStream {
  private let bytes: [UInt8]
  private var bytePos: Int = 0
  private var bitPos: Int = 0
  private var currentByte: Int

  init(_ data: [UInt8]) {
    self.bytes = data
    self.currentByte = data.count > 0 ? Int(data[0]) : 0
  }

  func readBit() -> Int {
    if bitPos == 8 {
      bytePos += 1
      bitPos = 0
      currentByte = bytePos < bytes.count ? Int(bytes[bytePos]) : 0
    }

    let bit = (currentByte >> (7 - bitPos)) & 1
    bitPos += 1
    return bit
  }
}

class ArithDecode: BenchmarkProtocol {
  var sizeVal: Int64 = 0
  var testData: [UInt8] = []
  var decoded: [UInt8] = []
  var encoded: ArithEncodedResult?
  var resultVal: UInt32 = 0

  required init() {
    sizeVal = configValue("size") ?? 0
  }

  func name() -> String {
    return "Compress::ArithDecode"
  }

  func prepare() {
    testData = generateTestData(sizeVal)

    let encoder = ArithEncode()
    encoder.sizeVal = sizeVal
    encoder.prepare()
    encoder.run(iterationId: 0)
    encoded = encoder.encoded
    resultVal = 0
  }

  func run(iterationId: Int) {
    decoded = arithDecode(encoded!)
    resultVal &+= UInt32(decoded.count)
  }

  var checksum: UInt32 {
    var res = resultVal
    if decoded == testData {
      res &+= 100000
    }
    return res
  }

  func arithDecode(_ encoded: ArithEncodedResult) -> [UInt8] {
    let frequencies = encoded.frequencies
    let total = frequencies.reduce(0, +)
    let dataSize = total

    var lowTable = [Int](repeating: 0, count: 256)
    var highTable = [Int](repeating: 0, count: 256)
    var cum = 0
    for i in 0..<256 {
      lowTable[i] = cum
      cum += frequencies[i]
      highTable[i] = cum
    }

    var result = [UInt8](repeating: 0, count: dataSize)
    let input = BitInputStream(encoded.data)

    var value: UInt64 = 0
    for _ in 0..<32 {
      value = (value << 1) | UInt64(input.readBit())
    }

    var low: UInt64 = 0
    var high: UInt64 = 0xFFFF_FFFF

    for j in 0..<dataSize {
      let range = high - low + 1
      let scaled = ((value - low + 1) * UInt64(total) - 1) / range

      var symbol = 0
      while symbol < 255 && UInt64(highTable[symbol]) <= scaled {
        symbol += 1
      }

      result[j] = UInt8(symbol)

      high = low + (range * UInt64(highTable[symbol]) / UInt64(total)) - 1
      low = low + (range * UInt64(lowTable[symbol]) / UInt64(total))

      while true {
        if high < 0x8000_0000 {

        } else if low >= 0x8000_0000 {
          value -= 0x8000_0000
          low -= 0x8000_0000
          high -= 0x8000_0000
        } else if low >= 0x4000_0000 && high < 0xC000_0000 {
          value -= 0x4000_0000
          low -= 0x4000_0000
          high -= 0x4000_0000
        } else {
          break
        }

        low <<= 1
        high = (high << 1) | 1
        value = (value << 1) | UInt64(input.readBit())
      }
    }

    return result
  }
}

struct LZWResult {
  let data: [UInt8]
  let dictSize: Int
}

class LZWEncode: BenchmarkProtocol {
  var sizeVal: Int64 = 0
  var testData: [UInt8] = []
  var encoded: LZWResult?
  var resultVal: UInt32 = 0

  required init() {
    sizeVal = configValue("size") ?? 0
  }

  func name() -> String {
    return "Compress::LZWEncode"
  }

  func prepare() {
    testData = generateTestData(sizeVal)
    resultVal = 0
  }

  func run(iterationId: Int) {
    encoded = lzwEncode(testData)
    resultVal &+= UInt32(encoded!.data.count)
  }

  var checksum: UInt32 {
    return resultVal
  }

  func lzwEncode(_ input: [UInt8]) -> LZWResult {
    if input.isEmpty {
      return LZWResult(data: [], dictSize: 256)
    }

    var dict = [String: Int]()
    for i in 0..<256 {

      let char = String(Character(UnicodeScalar(i)!))
      dict[char] = i
    }

    var nextCode = 256
    var result = [UInt8]()
    result.reserveCapacity(input.count * 2)

    var current = String(Character(UnicodeScalar(input[0])))

    for i in 1..<input.count {

      let nextChar = String(Character(UnicodeScalar(input[i])))
      let newStr = current + nextChar

      if dict[newStr] != nil {
        current = newStr
      } else {
        let code = dict[current]!
        result.append(UInt8((code >> 8) & 0xFF))
        result.append(UInt8(code & 0xFF))

        dict[newStr] = nextCode
        nextCode += 1
        current = nextChar
      }
    }

    let code = dict[current]!
    result.append(UInt8((code >> 8) & 0xFF))
    result.append(UInt8(code & 0xFF))

    return LZWResult(data: result, dictSize: nextCode)
  }
}

class LZWDecode: BenchmarkProtocol {
  var sizeVal: Int64 = 0
  var testData: [UInt8] = []
  var decoded: [UInt8] = []
  var encoded: LZWResult?
  var resultVal: UInt32 = 0

  required init() {
    sizeVal = configValue("size") ?? 0
  }

  func name() -> String {
    return "Compress::LZWDecode"
  }

  func prepare() {
    testData = generateTestData(sizeVal)

    let encoder = LZWEncode()
    encoder.sizeVal = sizeVal
    encoder.prepare()
    encoder.run(iterationId: 0)
    encoded = encoder.encoded
    resultVal = 0
  }

  func run(iterationId: Int) {
    decoded = lzwDecode(encoded!)
    resultVal &+= UInt32(decoded.count)
  }

  var checksum: UInt32 {
    var res = resultVal
    if decoded == testData {
      res &+= 100000
    }
    return res
  }

  func lzwDecode(_ encoded: LZWResult) -> [UInt8] {
    if encoded.data.isEmpty {
      return []
    }

    var dict = [String]()
    dict.reserveCapacity(4096)

    for i in 0..<256 {
      dict.append(String(UnicodeScalar(i)!))
    }

    var result = [UInt8]()
    result.reserveCapacity(encoded.data.count * 2)

    let data = encoded.data
    var pos = 0

    let oldCode = (Int(data[pos]) << 8) | Int(data[pos + 1])
    pos += 2

    var oldStr = dict[oldCode]

    result.append(contentsOf: oldStr.utf8)

    var nextCode = 256

    while pos < data.count {
      let newCode = (Int(data[pos]) << 8) | Int(data[pos + 1])
      pos += 2

      let newStr: String
      if newCode < dict.count {
        newStr = dict[newCode]
      } else {

        let firstChar = String(oldStr[oldStr.startIndex])
        newStr = oldStr + firstChar
      }

      result.append(contentsOf: newStr.utf8)

      let firstChar = String(newStr[newStr.startIndex])
      dict.append(oldStr + firstChar)
      nextCode += 1

      oldStr = newStr
    }

    return result
  }
}
