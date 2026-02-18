package benchmarks

import Benchmark
import java.util.Base64

class Base64Encode : Benchmark() {
    private var n: Long = 0
    private lateinit var bytes: ByteArray
    private lateinit var str2: String
    private var resultVal: UInt = 0u

    init {
        n = configVal("size")
    }

    override fun prepare() {
        val str = "a".repeat(n.toInt())
        bytes = str.toByteArray()
        str2 = Base64.getEncoder().encodeToString(bytes)
    }

    override fun run(iterationId: Int) {
        val encoded = Base64.getEncoder().encodeToString(bytes)
        resultVal += encoded.length.toUInt()  
    }

    override fun checksum(): UInt {
        val str = String(bytes.copyOfRange(0, 4))
        val message = "encode ${str.take(4)}... to ${str2.take(4)}...: $resultVal"
        return Helper.checksum(message)
    }

    override fun name(): String = "Base64Encode"
}