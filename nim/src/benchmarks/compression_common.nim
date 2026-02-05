import std/[algorithm, heapqueue, sequtils, strutils, tables]
import ../benchmark
import ../helper

type
  BWTResult* = object
    transformed: seq[byte]
    originalIdx: int

  HuffmanNode* = ref object
    frequency: int
    byteVal: byte
    isLeaf: bool
    left: HuffmanNode
    right: HuffmanNode

  HuffmanCodes* = object
    codeLengths: array[256, int]
    codes: array[256, int]

  CompressedData* = object
    bwtResult*: BWTResult
    frequencies*: seq[int]
    encodedBits*: seq[byte]
    originalBitCount*: int

proc `<`(a, b: HuffmanNode): bool =
  a.frequency < b.frequency

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

  result = newSeqOfCap[byte](n)  
  var idx = bwtResult.originalIdx

  for i in 0..<n:
    idx = next[idx]
    result.add(bwt[idx])

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

proc huffmanEncode*(data: seq[byte], codes: HuffmanCodes): tuple[data: seq[byte], bitCount: int] =
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
  (data: resultData, bitCount: totalBits)

proc huffmanDecode*(encoded: seq[byte], root: HuffmanNode, bitCount: int): seq[byte] =
  var resultData: seq[byte]
  resultData = newSeqOfCap[byte](bitCount div 4 + 1)  

  var currentNode = root
  var bitsProcessed = 0
  var byteIndex = 0

  while bitsProcessed < bitCount and byteIndex < encoded.len:
    var byteVal = encoded[byteIndex]
    inc byteIndex

    if bitsProcessed + 8 <= bitCount:

      for bitPos in countdown(7, 0):
        let bit = ((byteVal shr bitPos) and 1) == 1
        currentNode = if bit: currentNode.right else: currentNode.left

        if currentNode.isLeaf:
          resultData.add(currentNode.byteVal)
          currentNode = root

      bitsProcessed += 8
    else:

      for bitPos in countdown(7, 0):
        if bitsProcessed >= bitCount:
          break

        let bit = ((byteVal shr bitPos) and 1) == 1
        currentNode = if bit: currentNode.right else: currentNode.left

        inc bitsProcessed

        if currentNode.isLeaf:
          resultData.add(currentNode.byteVal)
          currentNode = root

  resultData

proc compressData*(data: seq[byte]): CompressedData =

  let bwtResult = bwtTransform(data)

  var frequencies = newSeq[int](256)
  for byteVal in bwtResult.transformed:
    inc frequencies[byteVal.int]

  let huffmanTree = buildHuffmanTree(frequencies)

  var huffmanCodes: HuffmanCodes
  buildHuffmanCodes(huffmanTree, 0, 0, huffmanCodes)

  let (encodedBits, bitCount) = huffmanEncode(bwtResult.transformed, huffmanCodes)

  CompressedData(
    bwtResult: bwtResult,
    frequencies: frequencies,
    encodedBits: encodedBits,
    originalBitCount: bitCount
  )

proc decompressData*(compressed: CompressedData): seq[byte] =

  let huffmanTree = buildHuffmanTree(compressed.frequencies)

  let decoded = huffmanDecode(compressed.encodedBits, huffmanTree, 
                             compressed.originalBitCount)

  let bwtResult = BWTResult(transformed: decoded, 
                           originalIdx: compressed.bwtResult.originalIdx)

  bwtInverse(bwtResult)

proc generateTestData*(size: int64): seq[byte] =
  const pattern = "ABRACADABRA"
  result = newSeq[byte](size.int)
  for i in 0..<size:
    result[i] = pattern[i mod pattern.len].byte