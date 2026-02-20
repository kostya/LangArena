package benchmarks

import java.util.PriorityQueue
import scala.collection.mutable.{HashMap, ArrayBuffer}

object Compress {
  def generateTestData(dataSize: Long): Array[Byte] = {
    val pattern = "ABRACADABRA".getBytes("UTF-8")
    Array.tabulate(dataSize.toInt) { i =>
      pattern(i % pattern.length)
    }
  }
}

class BWTResult(val transformed: Array[Byte], val originalIdx: Int)

class BWTEncode extends Benchmark {
  var sizeVal: Long = 0L
  protected var testData: Array[Byte] = _
  var bwtResult: BWTResult = _
  var resultVal: Long = 0L

  sizeVal = configVal("size")

  override def name(): String = "Compress::BWTEncode"

  override def prepare(): Unit = {
    testData = Compress.generateTestData(sizeVal)
    resultVal = 0L
  }

  override def run(iterationId: Int): Unit = {
    bwtResult = bwtTransform(testData)
    resultVal += bwtResult.transformed.length.toLong
  }

  override def checksum(): Long = resultVal & 0xffffffffL

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
}

class BWTDecode extends Benchmark {
  protected var sizeVal: Long = 0L
  protected var testData: Array[Byte] = _
  protected var inverted: Array[Byte] = _
  protected var bwtResult: BWTResult = _
  protected var resultVal: Long = 0L

  sizeVal = configVal("size")

  override def name(): String = "Compress::BWTDecode"

  override def prepare(): Unit = {
    testData = Compress.generateTestData(sizeVal)

    val encoder = new BWTEncode()
    encoder.sizeVal = sizeVal
    encoder.prepare()
    encoder.run(0)
    bwtResult = encoder.bwtResult
    resultVal = 0L
  }

  override def run(iterationId: Int): Unit = {
    inverted = bwtInverse(bwtResult)
    resultVal += inverted.length.toLong
  }

  override def checksum(): Long = {
    var res = resultVal
    if (java.util.Arrays.equals(inverted, testData)) {
      res += 100000L
    }
    res & 0xffffffffL
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

class HuffmanCodes(
    val codeLengths: Array[Int] = new Array[Int](256),
    val codes: Array[Int] = new Array[Int](256)
)

class EncodedResult(val data: Array[Byte], val bitCount: Int, val frequencies: Array[Int])

class HuffEncode extends Benchmark {
  var sizeVal: Long = 0L
  protected var testData: Array[Byte] = _
  var encoded: EncodedResult = _
  protected var resultVal: Long = 0L

  sizeVal = configVal("size")

  override def name(): String = "Compress::HuffEncode"

  override def prepare(): Unit = {
    testData = Compress.generateTestData(sizeVal)
    resultVal = 0L
  }

  override def run(iterationId: Int): Unit = {
    val frequencies = new Array[Int](256)
    var i = 0
    while (i < testData.length) {
      frequencies(testData(i) & 0xff) += 1
      i += 1
    }

    val tree = HuffEncode.buildHuffmanTree(frequencies)

    val codes = new HuffmanCodes()
    buildHuffmanCodes(tree, 0, 0, codes)

    encoded = huffmanEncode(testData, codes, frequencies)
    resultVal += encoded.data.length.toLong
  }

  override def checksum(): Long = resultVal & 0xffffffffL

  protected def buildHuffmanCodes(
      node: HuffmanNode,
      code: Int,
      length: Int,
      huffmanCodes: HuffmanCodes
  ): Unit = {
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
  }

  protected def huffmanEncode(
      data: Array[Byte],
      huffmanCodes: HuffmanCodes,
      frequencies: Array[Int]
  ): EncodedResult = {

    val result = Array.newBuilder[Byte]
    result.sizeHint(data.length * 2)

    var currentByte = 0
    var bitPos = 0
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
          result += currentByte.toByte
          currentByte = 0
          bitPos = 0
        }
        j -= 1
      }
      i += 1
    }

    if (bitPos > 0) {
      result += currentByte.toByte
    }

    new EncodedResult(result.result(), totalBits, frequencies)
  }
}

object HuffEncode {
  def buildHuffmanTree(frequencies: Array[Int]): HuffmanNode = {
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
}

class HuffDecode extends Benchmark {
  protected var sizeVal: Long = 0L
  protected var testData: Array[Byte] = _
  protected var decoded: Array[Byte] = _
  protected var encoded: EncodedResult = _
  protected var resultVal: Long = 0L

  sizeVal = configVal("size")

  override def name(): String = "Compress::HuffDecode"

  override def prepare(): Unit = {
    testData = Compress.generateTestData(sizeVal)

    val encoder = new HuffEncode()
    encoder.sizeVal = sizeVal
    encoder.prepare()
    encoder.run(0)
    encoded = encoder.encoded
    resultVal = 0L
  }

  override def run(iterationId: Int): Unit = {
    val tree = HuffEncode.buildHuffmanTree(encoded.frequencies)
    decoded = huffmanDecode(encoded.data, tree, encoded.bitCount)
    resultVal += decoded.length.toLong
  }

  override def checksum(): Long = {
    var res = resultVal
    if (java.util.Arrays.equals(decoded, testData)) {
      res += 100000L
    }
    res & 0xffffffffL
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
}

import scala.collection.mutable.ArrayBuffer

class ArithFreqTable(frequencies: Array[Int]) {
  val total: Int = frequencies.sum
  val low: Array[Int] = new Array[Int](256)
  val high: Array[Int] = new Array[Int](256)

  var cum: Int = 0
  var i: Int = 0
  while (i < 256) {
    low(i) = cum
    cum += frequencies(i)
    high(i) = cum
    i += 1
  }
}

class BitOutputStream {
  private var buffer: Int = 0
  private var bitPos: Int = 0
  private val bytes = ArrayBuffer.empty[Byte]
  private var bitsWritten: Int = 0

  def writeBit(bit: Int): Unit = {
    buffer = (buffer << 1) | (bit & 1)
    bitPos += 1
    bitsWritten += 1

    if (bitPos == 8) {
      bytes += buffer.toByte
      buffer = 0
      bitPos = 0
    }
  }

  def flush(): Array[Byte] = {
    if (bitPos > 0) {
      buffer <<= (8 - bitPos)
      bytes += buffer.toByte
    }
    bytes.toArray
  }

  def getBitsWritten: Int = bitsWritten

  def clear(): Unit = {
    buffer = 0
    bitPos = 0
    bytes.clear()
    bitsWritten = 0
  }
}

class ArithEncodedResult(
    val data: Array[Byte],
    val bitCount: Int,
    val frequencies: Array[Int]
)

class ArithEncode extends Benchmark {
  var sizeVal: Long = 0L
  var testData: Array[Byte] = _
  var encoded: ArithEncodedResult = _
  var resultVal: Long = 0L

  sizeVal = configVal("size")

  override def name(): String = "Compress::ArithEncode"

  override def prepare(): Unit = {
    testData = Compress.generateTestData(sizeVal)
    resultVal = 0L
  }

  override def run(iterationId: Int): Unit = {
    encoded = arithEncode(testData)
    resultVal += encoded.data.length.toLong
  }

  override def checksum(): Long = resultVal & 0xffffffffL

  protected def arithEncode(data: Array[Byte]): ArithEncodedResult = {
    val frequencies = new Array[Int](256)
    var i = 0
    while (i < data.length) {
      frequencies(data(i) & 0xff) += 1
      i += 1
    }

    val freqTable = new ArithFreqTable(frequencies)

    var low: Long = 0L
    var high: Long = 0xffffffffL
    var pending: Int = 0
    val output = new BitOutputStream()

    i = 0
    while (i < data.length) {
      val idx = data(i) & 0xff
      val range = high - low + 1

      high = low + (range * freqTable.high(idx) / freqTable.total) - 1
      low = low + (range * freqTable.low(idx) / freqTable.total)

      var cont = true
      while (cont) {
        if (high < 0x80000000L) {
          output.writeBit(0)
          var j = 0
          while (j < pending) {
            output.writeBit(1)
            j += 1
          }
          pending = 0
        } else if (low >= 0x80000000L) {
          output.writeBit(1)
          var j = 0
          while (j < pending) {
            output.writeBit(0)
            j += 1
          }
          pending = 0
          low -= 0x80000000L
          high -= 0x80000000L
        } else if (low >= 0x40000000L && high < 0xc0000000L) {
          pending += 1
          low -= 0x40000000L
          high -= 0x40000000L
        } else {
          cont = false
        }

        low <<= 1
        high = (high << 1) | 1
        high &= 0xffffffffL
      }
      i += 1
    }

    pending += 1
    if (low < 0x40000000L) {
      output.writeBit(0)
      var j = 0
      while (j < pending) {
        output.writeBit(1)
        j += 1
      }
    } else {
      output.writeBit(1)
      var j = 0
      while (j < pending) {
        output.writeBit(0)
        j += 1
      }
    }

    new ArithEncodedResult(output.flush(), output.getBitsWritten, frequencies)
  }
}

class BitInputStream(val data: Array[Byte]) {
  private var bytePos: Int = 0
  private var bitPos: Int = 0
  private var currentByte: Int = if (data.length > 0) data(0) & 0xff else 0

  def readBit(): Int = {
    if (bitPos == 8) {
      bytePos += 1
      bitPos = 0
      currentByte = if (bytePos < data.length) data(bytePos) & 0xff else 0
    }

    val bit = (currentByte >> (7 - bitPos)) & 1
    bitPos += 1
    bit
  }
}

class ArithDecode extends Benchmark {
  protected var sizeVal: Long = 0L
  protected var testData: Array[Byte] = _
  protected var decoded: Array[Byte] = _
  protected var encoded: ArithEncodedResult = _
  protected var resultVal: Long = 0L

  sizeVal = configVal("size")

  override def name(): String = "Compress::ArithDecode"

  override def prepare(): Unit = {
    testData = Compress.generateTestData(sizeVal)

    val encoder = new ArithEncode()
    encoder.sizeVal = sizeVal
    encoder.prepare()
    encoder.run(0)
    encoded = encoder.encoded
    resultVal = 0L
  }

  override def run(iterationId: Int): Unit = {
    decoded = arithDecode(encoded)
    resultVal += decoded.length.toLong
  }

  override def checksum(): Long = {
    var res = resultVal & 0xffffffffL
    if (java.util.Arrays.equals(decoded, testData)) {
      res += 100000L
    }
    res
  }

  protected def arithDecode(encoded: ArithEncodedResult): Array[Byte] = {
    val frequencies = encoded.frequencies
    val total = frequencies.sum
    val dataSize = total

    val lowTable = new Array[Int](256)
    val highTable = new Array[Int](256)
    var cum = 0
    var i = 0
    while (i < 256) {
      lowTable(i) = cum
      cum += frequencies(i)
      highTable(i) = cum
      i += 1
    }

    val result = new Array[Byte](dataSize)
    val input = new BitInputStream(encoded.data)

    var value: Long = 0L
    i = 0
    while (i < 32) {
      value = (value << 1) | input.readBit()
      i += 1
    }

    var low: Long = 0L
    var high: Long = 0xffffffffL

    var j = 0
    while (j < dataSize) {
      val range = high - low + 1
      val scaled = ((value - low + 1) * total - 1) / range

      var symbol = 0
      while (symbol < 255 && highTable(symbol) <= scaled) {
        symbol += 1
      }

      result(j) = symbol.toByte

      high = low + (range * highTable(symbol) / total) - 1
      low = low + (range * lowTable(symbol) / total)

      var cont = true
      while (cont) {
        if (high < 0x80000000L) {}
        else if (low >= 0x80000000L) {
          value -= 0x80000000L
          low -= 0x80000000L
          high -= 0x80000000L
        } else if (low >= 0x40000000L && high < 0xc0000000L) {
          value -= 0x40000000L
          low -= 0x40000000L
          high -= 0x40000000L
        } else {
          cont = false
        }

        if (cont) {
          low <<= 1
          high = (high << 1) | 1
          value = (value << 1) | input.readBit()
          value &= 0xffffffffL
        }
      }
      j += 1
    }

    result
  }
}

class LZWResult(val data: Array[Byte], val dictSize: Int)

class LZWEncode extends Benchmark {
  var sizeVal: Long = 0L
  protected var testData: Array[Byte] = _
  var encoded: LZWResult = _
  protected var resultVal: Long = 0L

  sizeVal = configVal("size")

  override def name(): String = "Compress::LZWEncode"

  override def prepare(): Unit = {
    testData = Compress.generateTestData(sizeVal)
    resultVal = 0L
  }

  override def run(iterationId: Int): Unit = {
    encoded = lzwEncode(testData)
    resultVal += encoded.data.length
  }

  override def checksum(): Long = resultVal & 0xffffffffL

  protected def lzwEncode(input: Array[Byte]): LZWResult = {
    if (input.length == 0) {
      return new LZWResult(new Array[Byte](0), 256)
    }

    val dict = new HashMap[String, Int]()

    var i = 0
    while (i < 256) {
      dict(new String(Array(i.toByte), "ISO-8859-1")) = i
      i += 1
    }

    var nextCode = 256
    val result = ArrayBuffer.empty[Byte]
    result.sizeHint(input.length * 2)

    var current = new String(Array(input(0)), "ISO-8859-1")

    i = 1
    while (i < input.length) {
      val nextChar = new String(Array(input(i)), "ISO-8859-1")
      val newStr = current + nextChar

      if (dict.contains(newStr)) {
        current = newStr
      } else {
        val code = dict(current)
        result += ((code >> 8) & 0xff).toByte
        result += ((code & 0xff).toByte)

        dict(newStr) = nextCode
        nextCode += 1
        current = nextChar
      }
      i += 1
    }

    val code = dict(current)
    result += ((code >> 8) & 0xff).toByte
    result += ((code & 0xff).toByte)

    new LZWResult(result.toArray, nextCode)
  }
}

class LZWDecode extends Benchmark {
  protected var sizeVal: Long = 0L
  protected var testData: Array[Byte] = _
  protected var decoded: Array[Byte] = _
  protected var encoded: LZWResult = _
  protected var resultVal: Long = 0L

  sizeVal = configVal("size")

  override def name(): String = "Compress::LZWDecode"

  override def prepare(): Unit = {
    testData = Compress.generateTestData(sizeVal)

    val encoder = new LZWEncode()
    encoder.sizeVal = sizeVal
    encoder.prepare()
    encoder.run(0)
    encoded = encoder.encoded
    resultVal = 0L
  }

  override def run(iterationId: Int): Unit = {
    decoded = lzwDecode(encoded)
    resultVal += decoded.length.toLong
  }

  override def checksum(): Long = {
    var res = resultVal
    if (java.util.Arrays.equals(decoded, testData)) {
      res += 100000L
    }
    res & 0xffffffffL
  }

  protected def lzwDecode(encoded: LZWResult): Array[Byte] = {
    if (encoded.data.length == 0) {
      return new Array[Byte](0)
    }

    import java.util.ArrayList
    import java.io.ByteArrayOutputStream

    val dict = new ArrayList[String](4096)
    var i = 0
    while (i < 256) {
      dict.add(new String(Array(i.toByte), "ISO-8859-1"))
      i += 1
    }

    val result = new ByteArrayOutputStream(encoded.data.length * 2)
    val data = encoded.data
    var pos = 0

    val oldCode = ((data(pos) & 0xff) << 8) | (data(pos + 1) & 0xff)
    pos += 2

    var oldStr = dict.get(oldCode)
    result.write(oldStr.getBytes("ISO-8859-1"))

    var nextCode = 256

    while (pos < data.length) {
      val newCode = ((data(pos) & 0xff) << 8) | (data(pos + 1) & 0xff)
      pos += 2

      val newStr = if (newCode < dict.size) {
        dict.get(newCode)
      } else {

        oldStr + oldStr.charAt(0).toString
      }

      result.write(newStr.getBytes("ISO-8859-1"))

      dict.add(oldStr + newStr.charAt(0).toString)
      nextCode += 1
      oldStr = newStr
    }

    result.toByteArray
  }
}
