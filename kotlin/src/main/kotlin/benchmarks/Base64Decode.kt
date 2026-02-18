package benchmarks

import Benchmark
import java.util.Base64

class Base64Decode : Benchmark() {
    private var n: Long = 0
    private lateinit var str2: String
    private lateinit var bytes: ByteArray
    private var resultVal: UInt = 0u

    init {
        n = configVal("size")
    }

    override fun prepare() {
        val str = "a".repeat(n.toInt())
        str2 = Base64.getEncoder().encodeToString(str.toByteArray())
        bytes = Base64.getDecoder().decode(str2)
    }

    override fun run(iterationId: Int) {
        bytes = Base64.getDecoder().decode(str2)
        resultVal += bytes.size.toUInt()  
    }

    override fun checksum(): UInt {
        val str3 = String(bytes.copyOfRange(0, 4))
        val message = "decode ${str2.take(4)}... to ${str3.take(4)}...: $resultVal"
        return Helper.checksum(message)
    }

    override fun name(): String = "Base64Decode"
}