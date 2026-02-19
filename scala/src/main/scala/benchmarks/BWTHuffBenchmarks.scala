package benchmarks

import java.util.PriorityQueue
import scala.collection.mutable.ArrayBuffer

class BWTHuffEncode extends Benchmark {
  protected var testData: Array[Byte] = _
  protected var resultVal: Long = 0L
  protected var sizeVal: Long = 0L

  sizeVal = configVal("size")

  class BWTResult(val transformed: Array[Byte], val originalIdx: Int)

  protected def bwtTransform(input: Array[Byte]): BWTResult = {
    val n = input.length
    if (n == 0) return new BWTResult(new Array[Byte](0), 0)

    val sa = new Array[Int](n)
    var i = 0
    while (i < n) {
      sa(i) = i
      i += 1
    }

    val count = new Array[Int](256)
    i = 0
    while (i < n) {
      count(input(i) & 0xff) += 1
      i += 1
    }

    val pos = new Array[Int](256)
    var sum = 0
    i = 0
    while (i < 256) {
      pos(i) = sum
      sum += count(i)
      i += 1
    }

    val tempPos = pos.clone()
    val sortedSA = new Array[Int](n)
    i = 0
    while (i < n) {
      val idx = sa(i)
      val c = input(idx) & 0xff
      sortedSA(tempPos(c)) = idx
      tempPos(c) += 1
      i += 1
    }
    System.arraycopy(sortedSA, 0, sa, 0, n)

    if (n > 1) {
      val rank = new Array[Int](n)
      var currentRank = 0
      var prevChar = input(sa(0)) & 0xff

      i = 0
      while (i < n) {
        val idx = sa(i)
        val currChar = input(idx) & 0xff
        if (currChar != prevChar) {
          currentRank += 1
          prevChar = currChar
        }
        rank(idx) = currentRank
        i += 1
      }

      var k = 1
      while (k < n) {

        sa.sortInPlaceWith { (a, b) =>
          val ra = rank(a)
          val rb = rank(b)
          if (ra != rb) ra < rb
          else {
            val rak = rank((a + k) % n)
            val rbk = rank((b + k) % n)
            rak < rbk
          }
        }

        val newRank = new Array[Int](n)
        newRank(sa(0)) = 0
        i = 1
        while (i < n) {
          val prevIdx = sa(i - 1)
          val currIdx = sa(i)
          newRank(currIdx) = newRank(prevIdx) + (
            if (
              rank(prevIdx) != rank(currIdx) ||
              rank((prevIdx + k) % n) != rank((currIdx + k) % n)
            ) 1
            else 0
          )
          i += 1
        }
        System.arraycopy(newRank, 0, rank, 0, n)
        k <<= 1
      }
    }

    val transformed = new Array[Byte](n)
    var originalIdx = 0

    i = 0
    while (i < n) {
      val suffix = sa(i)
      if (suffix == 0) {
        transformed(i) = input(n - 1)
        originalIdx = i
      } else {
        transformed(i) = input(suffix - 1)
      }
      i += 1
    }

    new BWTResult(transformed, originalIdx)
  }

  protected def bwtInverse(bwtResult: BWTResult): Array[Byte] = {
    val bwt = bwtResult.transformed
    val n = bwt.length
    if (n == 0) return new Array[Byte](0)

    val counts = new Array[Int](256)
    var i = 0
    while (i < n) {
      counts(bwt(i) & 0xff) += 1
      i += 1
    }

    val positions = new Array[Int](256)
    var total = 0
    i = 0
    while (i < 256) {
      positions(i) = total
      total += counts(i)
      i += 1
    }

    val next = new Array[Int](n)
    val tempCounts = new Array[Int](256)

    i = 0
    while (i < n) {
      val byteIdx = bwt(i) & 0xff
      val pos = positions(byteIdx) + tempCounts(byteIdx)
      next(pos) = i
      tempCounts(byteIdx) += 1
      i += 1
    }

    val result = new Array[Byte](n)
    var idx = bwtResult.originalIdx

    i = 0
    while (i < n) {
      idx = next(idx)
      result(i) = bwt(idx)
      i += 1
    }

    result
  }

  class HuffmanNode(
      var frequency: Int,
      var byteVal: Byte,
      var isLeaf: Boolean,
      var left: HuffmanNode,
      var right: HuffmanNode
  ) extends Comparable[HuffmanNode] {
    override def compareTo(other: HuffmanNode): Int = this.frequency - other.frequency
  }

  protected def buildHuffmanTree(frequencies: Array[Int]): HuffmanNode = {
    val heap = new PriorityQueue[HuffmanNode]()

    var i = 0
    while (i < 256) {
      if (frequencies(i) > 0) {
        heap.offer(new HuffmanNode(frequencies(i), i.toByte, true, null, null))
      }
      i += 1
    }

    if (heap.size == 1) {
      val node = heap.poll()
      return new HuffmanNode(
        node.frequency,
        (-1).toByte,
        false,
        node,
        new HuffmanNode(0, 0.toByte, true, null, null)
      )
    }

    while (heap.size > 1) {
      val left = heap.poll()
      val right = heap.poll()

      val parent = new HuffmanNode(
        left.frequency + right.frequency,
        (-1).toByte,
        false,
        left,
        right
      )

      heap.offer(parent)
    }

    heap.poll()
  }

  class HuffmanCodes(
      val codeLengths: Array[Int] = new Array[Int](256),
      val codes: Array[Int] = new Array[Int](256)
  )

  protected def buildHuffmanCodes(
      node: HuffmanNode,
      code: Int = 0,
      length: Int = 0,
      huffmanCodes: HuffmanCodes = new HuffmanCodes()
  ): HuffmanCodes = {
    if (node.isLeaf) {
      if (length > 0 || node.byteVal != 0.toByte) {
        val idx = node.byteVal & 0xff
        huffmanCodes.codeLengths(idx) = length
        huffmanCodes.codes(idx) = code
      }
    } else {
      if (node.left != null) {
        buildHuffmanCodes(node.left, code << 1, length + 1, huffmanCodes)
      }
      if (node.right != null) {
        buildHuffmanCodes(node.right, (code << 1) | 1, length + 1, huffmanCodes)
      }
    }
    huffmanCodes
  }

  class EncodedResult(val data: Array[Byte], val bitCount: Int)

  protected def huffmanEncode(data: Array[Byte], huffmanCodes: HuffmanCodes): EncodedResult = {
    val result = new Array[Byte](data.length * 2)
    var currentByte = 0
    var bitPos = 0
    var byteIndex = 0
    var totalBits = 0

    var i = 0
    while (i < data.length) {
      val idx = data(i) & 0xff
      val code = huffmanCodes.codes(idx)
      val length = huffmanCodes.codeLengths(idx)

      var j = length - 1
      while (j >= 0) {
        if ((code & (1 << j)) != 0) {
          currentByte |= (1 << (7 - bitPos))
        }
        bitPos += 1
        totalBits += 1

        if (bitPos == 8) {
          result(byteIndex) = currentByte.toByte
          byteIndex += 1
          currentByte = 0
          bitPos = 0
        }
        j -= 1
      }
      i += 1
    }

    if (bitPos > 0) {
      result(byteIndex) = currentByte.toByte
      byteIndex += 1
    }

    val finalData = new Array[Byte](byteIndex)
    System.arraycopy(result, 0, finalData, 0, byteIndex)
    new EncodedResult(finalData, totalBits)
  }

  protected def huffmanDecode(encoded: Array[Byte], root: HuffmanNode, bitCount: Int): Array[Byte] = {
    val result = new Array[Byte](bitCount)
    var resultPos = 0
    var currentNode = root
    var bitsProcessed = 0
    var byteIndex = 0

    while (bitsProcessed < bitCount && byteIndex < encoded.length) {
      val byteVal = encoded(byteIndex) & 0xff
      byteIndex += 1

      var bitPos = 7
      while (bitPos >= 0 && bitsProcessed < bitCount) {
        val bit = ((byteVal >> bitPos) & 1) == 1
        bitsProcessed += 1

        currentNode = if (bit) currentNode.right else currentNode.left

        if (currentNode.isLeaf) {
          if (currentNode.byteVal != 0.toByte) {
            result(resultPos) = currentNode.byteVal
            resultPos += 1
          }
          currentNode = root
        }
        bitPos -= 1
      }
    }

    if (resultPos == result.length) result
    else {
      val trimmed = new Array[Byte](resultPos)
      System.arraycopy(result, 0, trimmed, 0, resultPos)
      trimmed
    }
  }

  class CompressedData(
      val bwtResult: BWTResult,
      val frequencies: Array[Int],
      val encodedBits: Array[Byte],
      val originalBitCount: Int
  )

  protected def compress(data: Array[Byte]): CompressedData = {
    val bwtResult = bwtTransform(data)

    val frequencies = new Array[Int](256)
    var i = 0
    while (i < bwtResult.transformed.length) {
      frequencies(bwtResult.transformed(i) & 0xff) += 1
      i += 1
    }

    val huffmanTree = buildHuffmanTree(frequencies)
    val huffmanCodes = buildHuffmanCodes(huffmanTree)
    val encoded = huffmanEncode(bwtResult.transformed, huffmanCodes)

    new CompressedData(bwtResult, frequencies, encoded.data, encoded.bitCount)
  }

  protected def decompress(compressed: CompressedData): Array[Byte] = {
    val huffmanTree = buildHuffmanTree(compressed.frequencies)
    val decoded = huffmanDecode(compressed.encodedBits, huffmanTree, compressed.originalBitCount)
    val bwtResult = new BWTResult(decoded, compressed.bwtResult.originalIdx)
    bwtInverse(bwtResult)
  }

  protected def generateTestData(dataSize: Long): Array[Byte] = {
    val pattern = "ABRACADABRA".getBytes
    val data = new Array[Byte](dataSize.toInt)
    var i = 0
    while (i < dataSize.toInt) {
      data(i) = pattern(i % pattern.length)
      i += 1
    }
    data
  }

  override def prepare(): Unit = {
    testData = generateTestData(sizeVal)
  }

  override def run(iterationId: Int): Unit = {
    val compressed = compress(testData)
    resultVal += compressed.encodedBits.length.toLong
  }

  override def checksum(): Long = resultVal & 0xffffffffL

  override def name(): String = "BWTHuffEncode"
}

class BWTHuffDecode extends BWTHuffEncode {
  private var compressedData: CompressedData = _
  private var decompressed: Array[Byte] = _

  override def name(): String = "BWTHuffDecode"

  override def prepare(): Unit = {
    testData = generateTestData(sizeVal)
    compressedData = compress(testData)
    resultVal = 0L
  }

  override def run(iterationId: Int): Unit = {
    decompressed = decompress(compressedData)
    resultVal += decompressed.length.toLong
  }

  override def checksum(): Long = {
    var res = resultVal
    if (java.util.Arrays.equals(testData, decompressed)) {
      res += 1000000L
    }
    res & 0xffffffffL
  }
}
