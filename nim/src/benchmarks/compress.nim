import std/[algorithm, heapqueue, sequtils, strutils, tables, math]
import ../benchmark
import ../helper

proc generateTestData*(size: int64): seq[byte] =
  const pattern = "ABRACADABRA"
  result = newSeq[byte](size.int)
  for i in 0..<size.int:
    result[i] = pattern[i mod pattern.len].byte

type
  BWTResult* = object
    transformed: seq[byte]
    originalIdx: int

  BWTEncode* = ref object of Benchmark
    sizeVal: int64
    testData: seq[byte]
    bwtResult: BWTResult
    resultVal: uint32

proc newBWTEncode(): Benchmark =
  BWTEncode(sizeVal: config_i64("Compress::BWTEncode", "size"))

method name(self: BWTEncode): string = "Compress::BWTEncode"

method prepare(self: BWTEncode) =
  self.testData = generateTestData(self.sizeVal)
  self.resultVal = 0

proc bwtTransform*(input: seq[byte]): BWTResult =
  let n = input.len
  if n == 0:
    return BWTResult(transformed: @[], originalIdx: 0)

  var doubled = newSeq[byte](n * 2)
  for i in 0..<n:
    doubled[i] = input[i]
    doubled[i + n] = input[i]

  var sa = newSeq[int](n)
  for i in 0..<n:
    sa[i] = i

  var buckets = newSeq[seq[int]](256)
  for i in 0..<256:
    buckets[i] = newSeq[int]()

  for idx in sa:
    let firstChar = input[idx]
    buckets[firstChar.int].add(idx)

  var pos = 0
  for bucket in buckets:
    for idx in bucket:
      sa[pos] = idx
      inc pos

  if n > 1:
    var rank = newSeq[int](n)
    var currentRank = 0
    var prevChar = input[sa[0]]

    for i in 0..<n:
      let idx = sa[i]
      let currChar = input[idx]
      if currChar != prevChar:
        inc currentRank
        prevChar = currChar
      rank[idx] = currentRank

    var k = 1
    while k < n:
      var pairs = newSeq[(int, int)](n)
      for i in 0..<n:
        pairs[i] = (rank[i], rank[(i + k) mod n])

      sa.sort(proc(a, b: int): int =
        let pairA = pairs[a]
        let pairB = pairs[b]
        if pairA[0] != pairB[0]:
          return cmp(pairA[0], pairB[0])
        return cmp(pairA[1], pairB[1])
      )

      var newRank = newSeq[int](n)
      newRank[sa[0]] = 0
      for i in 1..<n:
        let prevPair = pairs[sa[i - 1]]
        let currPair = pairs[sa[i]]
        newRank[sa[i]] = newRank[sa[i - 1]] +
          (if prevPair != currPair: 1 else: 0)

      rank = newRank
      k *= 2

  var transformed = newSeq[byte](n)
  var originalIdx = 0

  for i in 0..<n:
    let suffix = sa[i]
    if suffix == 0:
      transformed[i] = input[n - 1]
      originalIdx = i
    else:
      transformed[i] = input[suffix - 1]

  BWTResult(transformed: transformed, originalIdx: originalIdx)

method run(self: BWTEncode, iteration_id: int) =
  self.bwtResult = bwtTransform(self.testData)
  self.resultVal = self.resultVal + uint32(self.bwtResult.transformed.len)

method checksum(self: BWTEncode): uint32 =
  self.resultVal

registerBenchmark("Compress::BWTEncode", newBWTEncode)

type
  BWTDecode* = ref object of Benchmark
    sizeVal: int64
    testData: seq[byte]
    inverted: seq[byte]
    bwtResult: BWTResult
    resultVal: uint32

proc newBWTDecode(): Benchmark =
  BWTDecode()

method name(self: BWTDecode): string = "Compress::BWTDecode"

method prepare(self: BWTDecode) =
  self.sizeVal = self.config_val("size")
  let encoder = BWTEncode()
  encoder.sizeVal = self.sizeVal
  encoder.prepare()
  encoder.run(0)
  self.testData = encoder.testData
  self.bwtResult = encoder.bwtResult
  self.resultVal = 0

proc bwtInverse*(bwtResult: BWTResult): seq[byte] =
  let bwt = bwtResult.transformed
  let n = bwt.len
  if n == 0:
    return @[]

  var counts: array[256, int]
  var positions: array[256, int]
  var tempCounts: array[256, int]

  for byteVal in bwt:
    inc counts[byteVal.int]

  var total = 0
  for i in 0..<256:
    positions[i] = total
    total += counts[i]

  var next = newSeq[int](n)

  for i in 0..<n:
    let byteVal = bwt[i].int
    let pos = positions[byteVal] + tempCounts[byteVal]
    next[pos] = i
    inc tempCounts[byteVal]

  var result = newSeq[byte](n)
  var idx = bwtResult.originalIdx

  for i in 0..<n:
    idx = next[idx]
    result[i] = bwt[idx]
  result

method run(self: BWTDecode, iteration_id: int) =
  self.inverted = bwtInverse(self.bwtResult)
  self.resultVal = self.resultVal + uint32(self.inverted.len)

method checksum(self: BWTDecode): uint32 =
  var res = self.resultVal
  if self.inverted == self.testData:
    res = res + 100000'u32
  res

registerBenchmark("Compress::BWTDecode", newBWTDecode)

type
  HuffmanNode* = ref object
    frequency: int
    byteVal: byte
    isLeaf: bool
    left: HuffmanNode
    right: HuffmanNode

  HuffmanCodes* = object
    codeLengths: array[256, int]
    codes: array[256, int]

  EncodedResult* = object
    data: seq[byte]
    bitCount: int
    frequencies: seq[int]

proc `<`(a, b: HuffmanNode): bool =
  a.frequency < b.frequency

type
  HuffEncode* = ref object of Benchmark
    sizeVal: int64
    testData: seq[byte]
    encoded: EncodedResult
    resultVal: uint32

proc newHuffEncode(): Benchmark =
  HuffEncode(sizeVal: config_i64("Compress::HuffEncode", "size"))

method name(self: HuffEncode): string = "Compress::HuffEncode"

method prepare(self: HuffEncode) =
  self.testData = generateTestData(self.sizeVal)
  self.resultVal = 0

proc buildHuffmanTree*(frequencies: seq[int]): HuffmanNode =
  var heap = initHeapQueue[HuffmanNode]()

  for i in 0..<256:
    if frequencies[i] > 0:
      let node = HuffmanNode(
        frequency: frequencies[i],
        byteVal: byte(i),
        isLeaf: true
      )
      heap.push(node)

  if heap.len == 1:
    let node = heap.pop()
    result = HuffmanNode(
      frequency: node.frequency,
      isLeaf: false,
      left: node,
      right: HuffmanNode(frequency: 0, byteVal: 0, isLeaf: true)
    )
    return

  while heap.len > 1:
    let left = heap.pop()
    let right = heap.pop()

    let parent = HuffmanNode(
      frequency: left.frequency + right.frequency,
      isLeaf: false,
      left: left,
      right: right
    )

    heap.push(parent)

  result = heap.pop()

proc buildHuffmanCodes*(node: HuffmanNode, code, length: int,
                       codes: var HuffmanCodes) =
  if node.isLeaf:
    if length > 0 or node.byteVal != 0:
      let idx = node.byteVal.int
      codes.codeLengths[idx] = length
      codes.codes[idx] = code
  else:
    if node.left != nil:
      buildHuffmanCodes(node.left, code shl 1, length + 1, codes)
    if node.right != nil:
      buildHuffmanCodes(node.right, (code shl 1) or 1, length + 1, codes)

proc huffmanEncode*(data: seq[byte], codes: HuffmanCodes,
                    frequencies: seq[int]): EncodedResult =
  var resultData = newSeq[byte](data.len * 2)
  var currentByte: byte = 0
  var bitPos = 0
  var byteIndex = 0
  var totalBits = 0

  for byteVal in data:
    let idx = byteVal.int
    let code = codes.codes[idx]
    let length = codes.codeLengths[idx]

    for i in countdown(length - 1, 0):
      if (code and (1 shl i)) != 0:
        currentByte = currentByte or (1'u8 shl (7 - bitPos))

      inc bitPos
      inc totalBits

      if bitPos == 8:
        resultData[byteIndex] = currentByte
        inc byteIndex
        currentByte = 0
        bitPos = 0

  if bitPos > 0:
    resultData[byteIndex] = currentByte
    inc byteIndex

  resultData.setLen(byteIndex)
  EncodedResult(data: resultData, bitCount: totalBits, frequencies: frequencies)

method run(self: HuffEncode, iteration_id: int) =
  var frequencies = newSeq[int](256)
  for byteVal in self.testData:
    inc frequencies[byteVal.int]

  let tree = buildHuffmanTree(frequencies)

  var codes: HuffmanCodes
  buildHuffmanCodes(tree, 0, 0, codes)

  self.encoded = huffmanEncode(self.testData, codes, frequencies)
  self.resultVal = self.resultVal + uint32(self.encoded.data.len)

method checksum(self: HuffEncode): uint32 =
  self.resultVal

registerBenchmark("Compress::HuffEncode", newHuffEncode)

type
  HuffDecode* = ref object of Benchmark
    sizeVal: int64
    testData: seq[byte]
    decoded: seq[byte]
    encoded: EncodedResult
    resultVal: uint32

proc newHuffDecode(): Benchmark =
  HuffDecode()

method name(self: HuffDecode): string = "Compress::HuffDecode"

method prepare(self: HuffDecode) =
  self.sizeVal = self.config_val("size")
  self.testData = generateTestData(self.sizeVal)

  let encoder = HuffEncode()
  encoder.sizeVal = self.sizeVal
  encoder.prepare()
  encoder.run(0)
  self.encoded = encoder.encoded
  self.resultVal = 0

proc huffmanDecode*(encoded: seq[byte], root: HuffmanNode, bitCount: int): seq[byte] =
  if encoded.len == 0 or root.isNil:
    return newSeq[byte]()

  var resultData = newSeqOfCap[byte](bitCount)

  var currentNode = root
  var bitsProcessed = 0
  var byteIndex = 0

  while bitsProcessed < bitCount and byteIndex < encoded.len:
    let byteVal = encoded[byteIndex]
    inc byteIndex

    for bitPos in countdown(7, 0):
      if bitsProcessed >= bitCount:
        break

      let bit = ((byteVal shr bitPos) and 1) == 1
      inc bitsProcessed

      currentNode = if bit: currentNode.right else: currentNode.left

      if currentNode.isLeaf:

        resultData.add(currentNode.byteVal)
        currentNode = root

  return resultData

method run(self: HuffDecode, iteration_id: int) =
  let tree = buildHuffmanTree(self.encoded.frequencies)
  self.decoded = huffmanDecode(self.encoded.data, tree, self.encoded.bitCount)
  self.resultVal = self.resultVal + uint32(self.decoded.len)

method checksum(self: HuffDecode): uint32 =
  var res = self.resultVal
  if self.decoded == self.testData:
    res = res + 100000'u32
  res

registerBenchmark("Compress::HuffDecode", newHuffDecode)

type
  ArithFreqTable = object
    total: int
    low: array[256, int]
    high: array[256, int]

  BitOutputStream = object
    buffer: uint8
    bitPos: int32
    bytes: seq[uint8]
    bitsWritten: int32

  ArithEncodedResult = object
    data: seq[uint8]
    bitCount: int32
    frequencies: seq[int]

  ArithEncode* = ref object of Benchmark
    sizeVal: int64
    testData: seq[byte]
    encoded: ArithEncodedResult
    resultVal: uint32

proc newArithEncode(): Benchmark =
  ArithEncode(sizeVal: config_i64("Compress::ArithEncode", "size"))

method name(self: ArithEncode): string = "Compress::ArithEncode"

method prepare(self: ArithEncode) =
  self.testData = generateTestData(self.sizeVal)
  self.resultVal = 0

proc newFreqTable(frequencies: seq[int]): ArithFreqTable =
  var total = 0
  for f in frequencies:
    total += f

  var low, high: array[256, int]
  var cum = 0
  for i in 0..<256:
    low[i] = cum
    cum += frequencies[i]
    high[i] = cum

  ArithFreqTable(total: total, low: low, high: high)

proc writeBit(stream: var BitOutputStream, bit: int32) =
  stream.buffer = uint8((stream.buffer.int shl 1) or (bit and 1))
  stream.bitPos += 1
  stream.bitsWritten += 1

  if stream.bitPos == 8:
    stream.bytes.add(stream.buffer)
    stream.buffer = 0
    stream.bitPos = 0

proc flush(stream: var BitOutputStream): seq[uint8] =
  if stream.bitPos > 0:
    stream.buffer = uint8(stream.buffer.int shl (8 - stream.bitPos))
    stream.bytes.add(stream.buffer)
  stream.bytes

proc arithEncode*(data: seq[byte]): ArithEncodedResult =
  var frequencies = newSeq[int](256)
  for byte in data:
    inc frequencies[byte.int]

  let freqTable = newFreqTable(frequencies)

  var low = 0'u64
  var high = 0xFFFFFFFF'u64
  var pending = 0
  var output = BitOutputStream(buffer: 0, bitPos: 0, bytes: @[], bitsWritten: 0)

  for byte in data:
    let idx = byte.int
    let range = high - low + 1

    high = low + (range * freqTable.high[
        idx].uint64 div freqTable.total.uint64) - 1
    low = low + (range * freqTable.low[idx].uint64 div freqTable.total.uint64)

    while true:
      if high < 0x80000000'u64:
        output.writeBit(0)
        for i in 0..<pending:
          output.writeBit(1)
        pending = 0
      elif low >= 0x80000000'u64:
        output.writeBit(1)
        for i in 0..<pending:
          output.writeBit(0)
        pending = 0
        low -= 0x80000000'u64
        high -= 0x80000000'u64
      elif low >= 0x40000000'u64 and high < 0xC0000000'u64:
        pending += 1
        low -= 0x40000000'u64
        high -= 0x40000000'u64
      else:
        break

      low = low shl 1
      high = (high shl 1) or 1
      high = high and 0xFFFFFFFF'u64

  pending += 1
  if low < 0x40000000'u64:
    output.writeBit(0)
    for i in 0..<pending:
      output.writeBit(1)
  else:
    output.writeBit(1)
    for i in 0..<pending:
      output.writeBit(0)

  let data = output.flush()
  ArithEncodedResult(data: data, bitCount: output.bitsWritten,
      frequencies: frequencies)

method run(self: ArithEncode, iteration_id: int) =
  self.encoded = arithEncode(self.testData)
  self.resultVal = self.resultVal + uint32(self.encoded.data.len)

method checksum(self: ArithEncode): uint32 =
  self.resultVal

registerBenchmark("Compress::ArithEncode", newArithEncode)

type
  BitInputStream = object
    bytes: seq[uint8]
    bytePos: int
    bitPos: int
    currentByte: uint8

  ArithDecode* = ref object of Benchmark
    sizeVal: int64
    testData: seq[byte]
    decoded: seq[byte]
    encoded: ArithEncodedResult
    resultVal: uint32

proc newArithDecode(): Benchmark =
  ArithDecode()

method name(self: ArithDecode): string = "Compress::ArithDecode"

method prepare(self: ArithDecode) =
  self.sizeVal = self.config_val("size")
  self.testData = generateTestData(self.sizeVal)

  let encoder = ArithEncode()
  encoder.sizeVal = self.sizeVal
  encoder.prepare()
  encoder.run(0)
  self.encoded = encoder.encoded
  self.resultVal = 0

proc initBitInputStream(bytes: seq[uint8]): BitInputStream =
  BitInputStream(
    bytes: bytes,
    bytePos: 0,
    bitPos: 0,
    currentByte: if bytes.len > 0: bytes[0] else: 0
  )

proc readBit(stream: var BitInputStream): int32 =
  if stream.bitPos == 8:
    stream.bytePos += 1
    stream.bitPos = 0
    stream.currentByte = if stream.bytePos < stream.bytes.len: stream.bytes[
        stream.bytePos] else: 0

  let bit = ((stream.currentByte shr (7 - stream.bitPos)) and 1).int32
  stream.bitPos += 1
  bit

proc arithDecode*(encoded: ArithEncodedResult): seq[byte] =
  let frequencies = encoded.frequencies
  var total = 0
  for f in frequencies:
    total += f
  let dataSize = total

  var lowTable: array[256, int]
  var highTable: array[256, int]
  var cum = 0
  for i in 0..<256:
    lowTable[i] = cum
    cum += frequencies[i]
    highTable[i] = cum

  var result = newSeq[byte](dataSize)
  var input = initBitInputStream(encoded.data)

  var value = 0'u64
  for i in 0..<32:
    value = (value shl 1) or input.readBit().uint64

  var low = 0'u64
  var high = 0xFFFFFFFF'u64

  for j in 0..<dataSize:
    let range = high - low + 1
    let scaled = ((value - low + 1) * total.uint64 - 1) div range

    var symbol = 0
    while symbol < 255 and highTable[symbol].uint64 <= scaled:
      symbol += 1

    result[j] = symbol.byte

    high = low + (range * highTable[symbol].uint64 div total.uint64) - 1
    low = low + (range * lowTable[symbol].uint64 div total.uint64)

    while true:
      if high < 0x80000000'u64:
        discard
      elif low >= 0x80000000'u64:
        value -= 0x80000000'u64
        low -= 0x80000000'u64
        high -= 0x80000000'u64
      elif low >= 0x40000000'u64 and high < 0xC0000000'u64:
        value -= 0x40000000'u64
        low -= 0x40000000'u64
        high -= 0x40000000'u64
      else:
        break

      low = low shl 1
      high = (high shl 1) or 1
      value = (value shl 1) or input.readBit().uint64

  result

method run(self: ArithDecode, iteration_id: int) =
  self.decoded = arithDecode(self.encoded)
  self.resultVal = self.resultVal + uint32(self.decoded.len)

method checksum(self: ArithDecode): uint32 =
  var res = self.resultVal
  if self.decoded == self.testData:
    res = res + 100000'u32
  res

registerBenchmark("Compress::ArithDecode", newArithDecode)

type
  LZWResult* = object
    data: seq[byte]
    dictSize: int

  LZWEncode* = ref object of Benchmark
    sizeVal: int64
    testData: seq[byte]
    encoded: LZWResult
    resultVal: uint32

proc newLZWEncode(): Benchmark =
  LZWEncode(sizeVal: config_i64("Compress::LZWEncode", "size"))

method name(self: LZWEncode): string = "Compress::LZWEncode"

method prepare(self: LZWEncode) =
  self.testData = generateTestData(self.sizeVal)
  self.resultVal = 0

proc lzwEncode*(input: seq[byte]): LZWResult =
  if input.len == 0:
    return LZWResult(data: @[], dictSize: 256)

  var dict = initTable[string, int](4096)
  for i in 0..<256:
    dict[$chr(i)] = i

  var nextCode = 256

  var resultData = newSeqOfCap[byte](input.len * 2)

  var current = $chr(input[0].int)

  for i in 1..<input.len:
    let nextChar = $chr(input[i].int)
    let newStr = current & nextChar

    if dict.hasKey(newStr):
      current = newStr
    else:
      let code = dict[current]

      resultData.add(((code shr 8) and 0xFF).byte)
      resultData.add((code and 0xFF).byte)

      dict[newStr] = nextCode
      nextCode += 1
      current = nextChar

  let code = dict[current]
  resultData.add(((code shr 8) and 0xFF).byte)
  resultData.add((code and 0xFF).byte)

  LZWResult(data: resultData, dictSize: nextCode)

method run(self: LZWEncode, iteration_id: int) =
  self.encoded = lzwEncode(self.testData)
  self.resultVal = self.resultVal + uint32(self.encoded.data.len)

method checksum(self: LZWEncode): uint32 =
  self.resultVal

registerBenchmark("Compress::LZWEncode", newLZWEncode)

type
  LZWDecode* = ref object of Benchmark
    sizeVal: int64
    testData: seq[byte]
    decoded: seq[byte]
    encoded: LZWResult
    resultVal: uint32

proc newLZWDecode(): Benchmark =
  LZWDecode()

method name(self: LZWDecode): string = "Compress::LZWDecode"

method prepare(self: LZWDecode) =
  self.sizeVal = self.config_val("size")
  self.testData = generateTestData(self.sizeVal)

  let encoder = LZWEncode()
  encoder.sizeVal = self.sizeVal
  encoder.prepare()
  encoder.run(0)
  self.encoded = encoder.encoded
  self.resultVal = 0

proc lzwDecode*(encoded: LZWResult): seq[byte] =
  if encoded.data.len == 0:
    return @[]

  var dict = newSeqOfCap[string](4096)
  for i in 0..<256:
    dict.add($chr(i))

  var resultData = newSeqOfCap[byte](encoded.data.len * 2)

  let data = encoded.data
  var pos = 0

  let oldCode = (data[pos].int shl 8) or data[pos + 1].int
  pos += 2

  var oldStr = dict[oldCode]

  for c in oldStr:
    resultData.add(c.byte)

  var nextCode = 256

  while pos < data.len:
    let newCode = (data[pos].int shl 8) or data[pos + 1].int
    pos += 2

    let newStr = if newCode < nextCode:
      dict[newCode]
    else:

      oldStr & oldStr[0]

    for c in newStr:
      resultData.add(c.byte)

    dict.add(oldStr & newStr[0])
    nextCode += 1
    oldStr = newStr

  return resultData

method run(self: LZWDecode, iteration_id: int) =
  self.decoded = lzwDecode(self.encoded)
  self.resultVal = self.resultVal + uint32(self.decoded.len)

method checksum(self: LZWDecode): uint32 =
  var res = self.resultVal
  if self.decoded == self.testData:
    res = res + 100000'u32
  res

registerBenchmark("Compress::LZWDecode", newLZWDecode)
