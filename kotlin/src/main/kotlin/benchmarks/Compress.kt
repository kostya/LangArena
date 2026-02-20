package benchmarks

import Benchmark
import java.util.*

class Compress {
    companion object {
        fun generateTestData(dataSize: Long): ByteArray {
            val pattern = "ABRACADABRA".toByteArray()
            val data = ByteArray(dataSize.toInt())

            for (i in 0 until dataSize.toInt()) {
                data[i] = pattern[i % pattern.size]
            }

            return data
        }
    }
}

class BWTEncode : Benchmark() {
    data class BWTResult(
        val transformed: ByteArray,
        val originalIdx: Int,
    )

    public lateinit var testData: ByteArray
    private var resultVal: UInt = 0u
    public var sizeVal: Long = 0
    public lateinit var bwtResult: BWTResult

    init {
        sizeVal = configVal("size")
    }

    override fun name(): String = "Compress::BWTEncode"

    override fun prepare() {
        testData = Compress.generateTestData(sizeVal)
        resultVal = 0u
    }

    override fun run(iterationId: Int) {
        bwtResult = bwtTransform(testData)
        resultVal += bwtResult.transformed.size.toUInt()
    }

    override fun checksum(): UInt = resultVal

    private fun bwtTransform(input: ByteArray): BWTResult {
        val n = input.size
        if (n == 0) {
            return BWTResult(ByteArray(0), 0)
        }

        val sa = Array(n) { it }

        val buckets = Array(256) { mutableListOf<Int>() }
        sa.forEach { idx ->
            val firstChar = input[idx].toInt() and 0xFF
            buckets[firstChar].add(idx)
        }

        var pos = 0
        buckets.forEach { bucket ->
            bucket.forEach { idx ->
                sa[pos++] = idx
            }
        }

        if (n > 1) {
            val rank = IntArray(n)
            var currentRank = 0
            var prevChar = input[sa[0]].toInt() and 0xFF

            sa.forEachIndexed { i, idx ->
                val currChar = input[idx].toInt() and 0xFF
                if (currChar != prevChar) {
                    currentRank++
                    prevChar = currChar
                }
                rank[idx] = currentRank
            }

            var k = 1
            while (k < n) {
                val pairs =
                    Array(n) { i ->
                        intArrayOf(rank[i], rank[(i + k) % n])
                    }

                sa.sortWith(
                    compareBy(
                        { pairs[it][0] },
                        { pairs[it][1] },
                    ),
                )

                val newRank = IntArray(n)
                newRank[sa[0]] = 0
                for (i in 1 until n) {
                    val prevPair = pairs[sa[i - 1]]
                    val currPair = pairs[sa[i]]
                    newRank[sa[i]] = newRank[sa[i - 1]] +
                        if (prevPair[0] != currPair[0] || prevPair[1] != currPair[1]) 1 else 0
                }

                System.arraycopy(newRank, 0, rank, 0, n)
                k *= 2
            }
        }

        val transformed = ByteArray(n)
        var originalIdx = 0

        sa.forEachIndexed { i, suffix ->
            if (suffix == 0) {
                transformed[i] = input[n - 1]
                originalIdx = i
            } else {
                transformed[i] = input[suffix - 1]
            }
        }

        return BWTResult(transformed, originalIdx)
    }
}

class BWTDecode : Benchmark() {
    private lateinit var testData: ByteArray
    private lateinit var inverted: ByteArray
    private lateinit var bwtResult: BWTEncode.BWTResult
    private var resultVal: UInt = 0u
    private var sizeVal: Long = 0

    init {
        sizeVal = configVal("size")
    }

    override fun name(): String = "Compress::BWTDecode"

    override fun prepare() {
        val encoder = BWTEncode()
        encoder.sizeVal = sizeVal
        encoder.prepare()
        encoder.run(0)
        testData = encoder.testData
        bwtResult = encoder.bwtResult
        resultVal = 0u
    }

    override fun run(iterationId: Int) {
        inverted = bwtInverse(bwtResult)
        resultVal += inverted.size.toUInt()
    }

    override fun checksum(): UInt {
        val res = resultVal
        if (inverted.contentEquals(testData)) {
            return res + 100000u
        }
        return res
    }

    private fun bwtInverse(bwtResult: BWTEncode.BWTResult): ByteArray {
        val bwt = bwtResult.transformed
        val n = bwt.size
        if (n == 0) {
            return ByteArray(0)
        }

        val counts = IntArray(256)
        bwt.forEach { byte ->
            counts[byte.toInt() and 0xFF]++
        }

        val positions = IntArray(256)
        var total = 0
        counts.forEachIndexed { i, count ->
            positions[i] = total
            total += count
        }

        val next = IntArray(n)
        val tempCounts = IntArray(256)

        bwt.forEachIndexed { i, byte ->
            val byteIdx = byte.toInt() and 0xFF
            val pos = positions[byteIdx] + tempCounts[byteIdx]
            next[pos] = i
            tempCounts[byteIdx]++
        }

        val result = ByteArray(n)
        var idx = bwtResult.originalIdx

        for (i in 0 until n) {
            idx = next[idx]
            result[i] = bwt[idx]
        }

        return result
    }
}

class HuffEncode : Benchmark() {
    data class HuffmanNode(
        val frequency: Int,
        val byteVal: Byte? = null,
        val isLeaf: Boolean = true,
        val left: HuffmanNode? = null,
        val right: HuffmanNode? = null,
    ) : Comparable<HuffmanNode> {
        override fun compareTo(other: HuffmanNode): Int = frequency.compareTo(other.frequency)
    }

    data class HuffmanCodes(
        val codeLengths: IntArray = IntArray(256),
        val codes: IntArray = IntArray(256),
    )

    data class EncodedResult(
        val data: ByteArray,
        val bitCount: Int,
        val frequencies: IntArray,
    )

    private lateinit var testData: ByteArray
    public lateinit var encoded: EncodedResult
    private var resultVal: UInt = 0u
    public var sizeVal: Long = 0

    init {
        sizeVal = configVal("size")
    }

    override fun name(): String = "Compress::HuffEncode"

    override fun prepare() {
        testData = Compress.generateTestData(sizeVal)
        resultVal = 0u
    }

    override fun run(iterationId: Int) {
        val frequencies = IntArray(256)
        for (byte in testData) {
            frequencies[byte.toInt() and 0xFF]++
        }

        val tree = buildHuffmanTree(frequencies)

        val codes = buildHuffmanCodes(tree)

        encoded = huffmanEncode(testData, codes, frequencies)
        resultVal += encoded.data.size.toUInt()
    }

    override fun checksum(): UInt = resultVal

    companion object {
        fun buildHuffmanTree(frequencies: IntArray): HuffmanNode {
            val heap = PriorityQueue<HuffmanNode>()

            frequencies.forEachIndexed { i, freq ->
                if (freq > 0) {
                    heap.offer(HuffmanNode(freq, i.toByte()))
                }
            }

            if (heap.size == 1) {
                val node = heap.poll()
                return HuffmanNode(
                    frequency = node.frequency,
                    byteVal = null,
                    isLeaf = false,
                    left = node,
                    right = HuffmanNode(0, 0),
                )
            }

            while (heap.size > 1) {
                val left = heap.poll()
                val right = heap.poll()

                val parent =
                    HuffmanNode(
                        frequency = left.frequency + right.frequency,
                        byteVal = null,
                        isLeaf = false,
                        left = left,
                        right = right,
                    )

                heap.offer(parent)
            }

            return heap.poll()
        }

        fun buildHuffmanCodes(
            node: HuffmanNode,
            code: Int = 0,
            length: Int = 0,
            huffmanCodes: HuffmanCodes = HuffmanCodes(),
        ): HuffmanCodes {
            if (node.isLeaf) {
                if (length > 0 || node.byteVal != 0.toByte()) {
                    val idx = node.byteVal!!.toInt() and 0xFF
                    huffmanCodes.codeLengths[idx] = length
                    huffmanCodes.codes[idx] = code
                }
            } else {
                node.left?.let {
                    buildHuffmanCodes(it, code shl 1, length + 1, huffmanCodes)
                }
                node.right?.let {
                    buildHuffmanCodes(it, (code shl 1) or 1, length + 1, huffmanCodes)
                }
            }
            return huffmanCodes
        }

        fun huffmanEncode(
            data: ByteArray,
            huffmanCodes: HuffmanCodes,
            frequencies: IntArray,
        ): EncodedResult {
            val result = ArrayList<Byte>(data.size * 2)
            var currentByte = 0
            var bitPos = 0
            var totalBits = 0

            data.forEach { byte ->
                val idx = byte.toInt() and 0xFF
                val code = huffmanCodes.codes[idx]
                val length = huffmanCodes.codeLengths[idx]

                for (i in length - 1 downTo 0) {
                    if ((code and (1 shl i)) != 0) {
                        currentByte = currentByte or (1 shl (7 - bitPos))
                    }
                    bitPos++
                    totalBits++

                    if (bitPos == 8) {
                        result.add(currentByte.toByte())
                        currentByte = 0
                        bitPos = 0
                    }
                }
            }

            if (bitPos > 0) {
                result.add(currentByte.toByte())
            }

            return EncodedResult(result.toByteArray(), totalBits, frequencies)
        }
    }
}

class HuffDecode : Benchmark() {
    private lateinit var testData: ByteArray
    private lateinit var decoded: ByteArray
    private lateinit var encoded: HuffEncode.EncodedResult
    private var resultVal: UInt = 0u
    private var sizeVal: Long = 0

    init {
        sizeVal = configVal("size")
    }

    override fun name(): String = "Compress::HuffDecode"

    override fun prepare() {
        testData = Compress.generateTestData(sizeVal)

        val encoder = HuffEncode()
        encoder.sizeVal = sizeVal
        encoder.prepare()
        encoder.run(0)
        encoded = encoder.encoded
        resultVal = 0u
    }

    override fun run(iterationId: Int) {
        val tree = HuffEncode.buildHuffmanTree(encoded.frequencies)
        decoded = huffmanDecode(encoded.data, tree, encoded.bitCount)
        resultVal += decoded.size.toUInt()
    }

    override fun checksum(): UInt {
        var res = resultVal
        if (decoded.contentEquals(testData)) {
            res += 100000u
        }
        return res
    }

    private fun huffmanDecode(
        encoded: ByteArray,
        root: HuffEncode.HuffmanNode,
        bitCount: Int,
    ): ByteArray {
        val result = ByteArray(bitCount)
        var resultSize = 0

        var currentNode = root
        var bitsProcessed = 0
        var byteIndex = 0

        while (bitsProcessed < bitCount && byteIndex < encoded.size) {
            val byteVal = encoded[byteIndex++].toInt() and 0xFF

            for (bitPos in 7 downTo 0) {
                if (bitsProcessed >= bitCount) break

                val bit = ((byteVal shr bitPos) and 1) == 1
                bitsProcessed++

                currentNode = if (bit) currentNode.right!! else currentNode.left!!

                if (currentNode.isLeaf) {
                    result[resultSize++] = currentNode.byteVal!!
                    currentNode = root
                }
            }
        }

        return result.copyOf(resultSize)
    }
}

class ArithEncode : Benchmark() {
    data class ArithEncodedResult(
        val data: ByteArray,
        val bitCount: Int,
        val frequencies: IntArray,
    )

    class ArithFreqTable(
        frequencies: IntArray,
    ) {
        val total: Int
        val low: IntArray
        val high: IntArray

        init {
            total = frequencies.sum()
            low = IntArray(256)
            high = IntArray(256)

            var cum = 0
            for (i in 0 until 256) {
                low[i] = cum
                cum += frequencies[i]
                high[i] = cum
            }
        }
    }

    class BitOutputStream {
        private var buffer: Int = 0
        private var bitPos: Int = 0
        private val bytes: MutableList<Byte> = mutableListOf()
        private var bitsWritten: Int = 0

        fun writeBit(bit: Int) {
            buffer = (buffer shl 1) or (bit and 1)
            bitPos++
            bitsWritten++

            if (bitPos == 8) {
                bytes.add(buffer.toByte())
                buffer = 0
                bitPos = 0
            }
        }

        fun flush(): ByteArray {
            if (bitPos > 0) {
                buffer = buffer shl (8 - bitPos)
                bytes.add(buffer.toByte())
            }
            return bytes.toByteArray()
        }

        fun getBitsWritten(): Int = bitsWritten
    }

    private lateinit var testData: ByteArray
    public lateinit var encoded: ArithEncodedResult
    private var resultVal: UInt = 0u
    public var sizeVal: Long = 0

    init {
        sizeVal = configVal("size")
    }

    override fun name(): String = "Compress::ArithEncode"

    override fun prepare() {
        testData = Compress.generateTestData(sizeVal)
        resultVal = 0u
    }

    override fun run(iterationId: Int) {
        encoded = arithEncode(testData)
        resultVal += encoded.data.size.toUInt()
    }

    override fun checksum(): UInt = resultVal

    private fun arithEncode(data: ByteArray): ArithEncodedResult {
        val frequencies = IntArray(256)
        for (byte in data) {
            frequencies[byte.toInt() and 0xFF]++
        }

        val freqTable = ArithFreqTable(frequencies)

        var low = 0uL
        var high = 0xFFFFFFFFuL
        var pending = 0
        val output = BitOutputStream()

        for (byte in data) {
            val idx = byte.toInt() and 0xFF
            val range = high - low + 1uL

            high = low + (range * freqTable.high[idx].toULong() / freqTable.total.toULong()) - 1uL
            low = low + (range * freqTable.low[idx].toULong() / freqTable.total.toULong())

            while (true) {
                if (high < 0x80000000uL) {
                    output.writeBit(0)
                    repeat(pending) { output.writeBit(1) }
                    pending = 0
                } else if (low >= 0x80000000uL) {
                    output.writeBit(1)
                    repeat(pending) { output.writeBit(0) }
                    pending = 0
                    low -= 0x80000000uL
                    high -= 0x80000000uL
                } else if (low >= 0x40000000uL && high < 0xC0000000uL) {
                    pending++
                    low -= 0x40000000uL
                    high -= 0x40000000uL
                } else {
                    break
                }

                low = low shl 1
                high = (high shl 1) or 1uL
                high = high and 0xFFFFFFFFuL
            }
        }

        pending++
        if (low < 0x40000000uL) {
            output.writeBit(0)
            repeat(pending) { output.writeBit(1) }
        } else {
            output.writeBit(1)
            repeat(pending) { output.writeBit(0) }
        }

        return ArithEncodedResult(output.flush(), output.getBitsWritten(), frequencies)
    }
}

class ArithDecode : Benchmark() {
    class BitInputStream(
        private val bytes: ByteArray,
    ) {
        private var bytePos: Int = 0
        private var bitPos: Int = 0
        private var currentByte: Int

        init {
            currentByte = if (bytes.isNotEmpty()) bytes[0].toInt() and 0xFF else 0
        }

        fun readBit(): Int {
            if (bitPos == 8) {
                bytePos++
                bitPos = 0
                currentByte = if (bytePos < bytes.size) bytes[bytePos].toInt() and 0xFF else 0
            }

            val bit = (currentByte shr (7 - bitPos)) and 1
            bitPos++
            return bit
        }
    }

    private lateinit var testData: ByteArray
    private lateinit var decoded: ByteArray
    private lateinit var encoded: ArithEncode.ArithEncodedResult
    private var resultVal: UInt = 0u
    private var sizeVal: Long = 0

    init {
        sizeVal = configVal("size")
    }

    override fun name(): String = "Compress::ArithDecode"

    override fun prepare() {
        testData = Compress.generateTestData(sizeVal)

        val encoder = ArithEncode()
        encoder.sizeVal = sizeVal
        encoder.prepare()
        encoder.run(0)
        encoded = encoder.encoded
        resultVal = 0u
    }

    override fun run(iterationId: Int) {
        decoded = arithDecode(encoded)
        resultVal += decoded.size.toUInt()
    }

    override fun checksum(): UInt {
        var res = resultVal
        if (decoded.contentEquals(testData)) {
            res += 100000u
        }
        return res
    }

    private fun arithDecode(encoded: ArithEncode.ArithEncodedResult): ByteArray {
        val frequencies = encoded.frequencies
        val total = frequencies.sum()
        val dataSize = total

        val lowTable = IntArray(256)
        val highTable = IntArray(256)
        var cum = 0
        for (i in 0 until 256) {
            lowTable[i] = cum
            cum += frequencies[i]
            highTable[i] = cum
        }

        val result = ByteArray(dataSize)
        val input = BitInputStream(encoded.data)

        var value = 0uL
        repeat(32) {
            value = (value shl 1) or input.readBit().toULong()
        }

        var low = 0uL
        var high = 0xFFFFFFFFuL

        for (j in 0 until dataSize) {
            val range = high - low + 1uL
            val scaled = ((value - low + 1uL) * total.toULong() - 1uL) / range

            var symbol = 0
            while (symbol < 255 && highTable[symbol].toULong() <= scaled) {
                symbol++
            }

            result[j] = symbol.toByte()

            high = low + (range * highTable[symbol].toULong() / total.toULong()) - 1uL
            low = low + (range * lowTable[symbol].toULong() / total.toULong())

            while (true) {
                if (high < 0x80000000uL) {
                } else if (low >= 0x80000000uL) {
                    value -= 0x80000000uL
                    low -= 0x80000000uL
                    high -= 0x80000000uL
                } else if (low >= 0x40000000uL && high < 0xC0000000uL) {
                    value -= 0x40000000uL
                    low -= 0x40000000uL
                    high -= 0x40000000uL
                } else {
                    break
                }

                low = low shl 1
                high = (high shl 1) or 1uL
                value = (value shl 1) or input.readBit().toULong()
            }
        }

        return result
    }
}

class LZWEncode : Benchmark() {
    data class LZWResult(
        val data: ByteArray,
        val dictSize: Int,
    )

    private lateinit var testData: ByteArray
    public lateinit var encoded: LZWResult
    private var resultVal: UInt = 0u
    public var sizeVal: Long = 0

    init {
        sizeVal = configVal("size")
    }

    override fun name(): String = "Compress::LZWEncode"

    override fun prepare() {
        testData = Compress.generateTestData(sizeVal)
        resultVal = 0u
    }

    override fun run(iterationId: Int) {
        encoded = lzwEncode(testData)
        resultVal += encoded.data.size.toUInt()
    }

    override fun checksum(): UInt = resultVal

    private fun lzwEncode(input: ByteArray): LZWResult {
        if (input.isEmpty()) {
            return LZWResult(byteArrayOf(), 256)
        }

        val dict = HashMap<String, Int>(4096)
        for (i in 0 until 256) {
            dict[i.toChar().toString()] = i
        }

        var nextCode = 256

        val result = ArrayList<Byte>(input.size * 2)

        var current = input[0].toInt().toChar().toString()

        for (i in 1 until input.size) {
            val nextChar = input[i].toInt().toChar().toString()
            val newStr = current + nextChar

            if (dict.containsKey(newStr)) {
                current = newStr
            } else {
                val code = dict[current]!!
                result.add(((code shr 8) and 0xFF).toByte())
                result.add((code and 0xFF).toByte())

                dict[newStr] = nextCode++
                current = nextChar
            }
        }

        val code = dict[current]!!
        result.add(((code shr 8) and 0xFF).toByte())
        result.add((code and 0xFF).toByte())

        return LZWResult(result.toByteArray(), nextCode)
    }
}

class LZWDecode : Benchmark() {
    private lateinit var testData: ByteArray
    private lateinit var decoded: ByteArray
    private lateinit var encoded: LZWEncode.LZWResult
    private var resultVal: UInt = 0u
    private var sizeVal: Long = 0

    init {
        sizeVal = configVal("size")
    }

    override fun name(): String = "Compress::LZWDecode"

    override fun prepare() {
        testData = Compress.generateTestData(sizeVal)

        val encoder = LZWEncode()
        encoder.sizeVal = sizeVal
        encoder.prepare()
        encoder.run(0)
        encoded = encoder.encoded
        resultVal = 0u
    }

    override fun run(iterationId: Int) {
        decoded = lzwDecode(encoded)
        resultVal += decoded.size.toUInt()
    }

    override fun checksum(): UInt {
        var res = resultVal
        if (decoded.contentEquals(testData)) {
            res += 100000u
        }
        return res
    }

    private fun lzwDecode(encoded: LZWEncode.LZWResult): ByteArray {
        if (encoded.data.isEmpty()) {
            return byteArrayOf()
        }

        val dict = ArrayList<String>(4096)
        for (i in 0 until 256) {
            dict.add(String(byteArrayOf(i.toByte()), Charsets.ISO_8859_1))
        }

        val result = java.io.ByteArrayOutputStream(encoded.data.size * 2)
        val data = encoded.data
        var pos = 0

        val high = data[pos].toInt() and 0xFF
        val low = data[pos + 1].toInt() and 0xFF
        var oldCode = (high shl 8) or low
        pos += 2

        var oldStr = dict[oldCode]
        result.write(oldStr.toByteArray(Charsets.ISO_8859_1))

        var nextCode = 256

        while (pos < data.size) {
            val high = data[pos].toInt() and 0xFF
            val low = data[pos + 1].toInt() and 0xFF
            val newCode = (high shl 8) or low
            pos += 2

            val newStr =
                if (newCode < dict.size) {
                    dict[newCode]
                } else {
                    oldStr + oldStr.substring(0, 1)
                }

            result.write(newStr.toByteArray(Charsets.ISO_8859_1))

            dict.add(oldStr + newStr.substring(0, 1))
            nextCode++
            oldStr = newStr
        }

        return result.toByteArray()
    }
}
