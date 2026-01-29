package benchmarks

import java.util.*

class Decompression : Compression() {
    private lateinit var compressedData: CompressedData
    private lateinit var decompressed: ByteArray
    
    init {
        // Уже инициализировано в родительском классе
    }
    
    override fun name(): String = "Decompression"
    
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