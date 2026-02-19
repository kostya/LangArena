package benchmarks

import java.util.*

class BWTHuffDecode : BWTHuffEncode() {
    private lateinit var compressedData: CompressedData
    private lateinit var decompressed: ByteArray

    init {
    }

    override fun name(): String = "BWTHuffDecode"

    override fun prepare() {
        testData = generateTestData(sizeVal)
        compressedData = compress(testData)
    }

    override fun run(iterationId: Int) {
        decompressed = decompress(compressedData)
        resultVal += decompressed.size.toUInt()
    }

    override fun checksum(): UInt {
        var res = resultVal
        if (testData.contentEquals(decompressed)) {
            res += 1000000u
        }
        return res
    }
}
