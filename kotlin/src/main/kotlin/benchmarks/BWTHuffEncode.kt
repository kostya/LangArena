package benchmarks

import java.util.*
import Benchmark

open class BWTHuffEncode : Benchmark() {
    protected lateinit var testData: ByteArray
    protected var resultVal: UInt = 0u
    protected var sizeVal: Long = 0

    init {
        sizeVal = configVal("size")
    }

    public data class BWTResult(
        val transformed: ByteArray,
        val originalIdx: Int
    ) {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (javaClass != other?.javaClass) return false

            other as BWTResult

            if (!transformed.contentEquals(other.transformed)) return false
            if (originalIdx != other.originalIdx) return false

            return true
        }

        override fun hashCode(): Int {
            var result = transformed.contentHashCode()
            result = 31 * result + originalIdx
            return result
        }
    }

    protected fun bwtTransform(input: ByteArray): BWTResult {
        val n = input.size
        if (n == 0) {
            return BWTResult(ByteArray(0), 0)
        }

        val doubled = ByteArray(n * 2)
        System.arraycopy(input, 0, doubled, 0, n)
        System.arraycopy(input, 0, doubled, n, n)

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

                val pairs = Array(n) { i ->
                    intArrayOf(rank[i], rank[(i + k) % n])
                }

                sa.sortWith(compareBy(
                    { pairs[it][0] },
                    { pairs[it][1] }
                ))

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

    protected fun bwtInverse(bwtResult: BWTResult): ByteArray {
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

    protected data class HuffmanNode(
        val frequency: Int,
        val byteVal: Byte? = null,
        val isLeaf: Boolean = true,
        val left: HuffmanNode? = null,
        val right: HuffmanNode? = null
    ) : Comparable<HuffmanNode> {
        override fun compareTo(other: HuffmanNode): Int {
            return frequency.compareTo(other.frequency)
        }
    }

    protected fun buildHuffmanTree(frequencies: IntArray): HuffmanNode {
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
                right = HuffmanNode(0, 0)
            )
        }

        while (heap.size > 1) {
            val left = heap.poll()
            val right = heap.poll()

            val parent = HuffmanNode(
                frequency = left.frequency + right.frequency,
                byteVal = null,
                isLeaf = false,
                left = left,
                right = right
            )

            heap.offer(parent)
        }

        return heap.poll()
    }

    protected data class HuffmanCodes(
        val codeLengths: IntArray = IntArray(256),
        val codes: IntArray = IntArray(256)
    )

    protected fun buildHuffmanCodes(
        node: HuffmanNode,
        code: Int = 0,
        length: Int = 0,
        huffmanCodes: HuffmanCodes = HuffmanCodes()
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

    protected data class EncodedResult(
        val data: ByteArray,
        val bitCount: Int
    ) {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (javaClass != other?.javaClass) return false

            other as EncodedResult

            if (!data.contentEquals(other.data)) return false
            if (bitCount != other.bitCount) return false

            return true
        }

        override fun hashCode(): Int {
            var result = data.contentHashCode()
            result = 31 * result + bitCount
            return result
        }
    }

    protected fun huffmanEncode(data: ByteArray, huffmanCodes: HuffmanCodes): EncodedResult {

        val result = ByteArray(data.size * 2)
        var currentByte = 0
        var bitPos = 0
        var byteIndex = 0
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
                    result[byteIndex++] = currentByte.toByte()
                    currentByte = 0
                    bitPos = 0
                }
            }
        }

        if (bitPos > 0) {
            result[byteIndex++] = currentByte.toByte()
        }

        return EncodedResult(result.copyOf(byteIndex), totalBits)
    }

    protected fun huffmanDecode(encoded: ByteArray, root: HuffmanNode, bitCount: Int): ByteArray {
        val result = mutableListOf<Byte>()
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
                    if (currentNode.byteVal != 0.toByte()) {
                        result.add(currentNode.byteVal!!)
                    }
                    currentNode = root
                }
            }
        }

        return result.toByteArray()
    }

    public data class CompressedData(
        val bwtResult: BWTResult,
        val frequencies: IntArray,
        val encodedBits: ByteArray,
        val originalBitCount: Int
    ) {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (javaClass != other?.javaClass) return false

            other as CompressedData

            if (bwtResult != other.bwtResult) return false
            if (!frequencies.contentEquals(other.frequencies)) return false
            if (!encodedBits.contentEquals(other.encodedBits)) return false
            if (originalBitCount != other.originalBitCount) return false

            return true
        }

        override fun hashCode(): Int {
            var result = bwtResult.hashCode()
            result = 31 * result + frequencies.contentHashCode()
            result = 31 * result + encodedBits.contentHashCode()
            result = 31 * result + originalBitCount
            return result
        }
    }

    protected fun compress(data: ByteArray): CompressedData {

        val bwtResult = bwtTransform(data)

        val frequencies = IntArray(256)
        bwtResult.transformed.forEach { byte ->
            frequencies[byte.toInt() and 0xFF]++
        }

        val huffmanTree = buildHuffmanTree(frequencies)

        val huffmanCodes = buildHuffmanCodes(huffmanTree)

        val encoded = huffmanEncode(bwtResult.transformed, huffmanCodes)

        return CompressedData(
            bwtResult,
            frequencies,
            encoded.data,
            encoded.bitCount
        )
    }

    protected fun decompress(compressed: CompressedData): ByteArray {

        val huffmanTree = buildHuffmanTree(compressed.frequencies)

        val decoded = huffmanDecode(
            compressed.encodedBits,
            huffmanTree,
            compressed.originalBitCount
        )

        val bwtResult = BWTResult(
            decoded,
            compressed.bwtResult.originalIdx
        )

        return bwtInverse(bwtResult)
    }

    protected fun generateTestData(dataSize: Long): ByteArray {
        val pattern = "ABRACADABRA".toByteArray()
        val data = ByteArray(dataSize.toInt())

        for (i in 0 until dataSize.toInt()) {
            data[i] = pattern[i % pattern.size]
        }

        return data
    }

    override fun prepare() {
        testData = generateTestData(sizeVal)
    }

    override fun run(iterationId: Int) {
        val compressed = compress(testData)
        resultVal += compressed.encodedBits.size.toUInt()  
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "BWTHuffEncode"
}