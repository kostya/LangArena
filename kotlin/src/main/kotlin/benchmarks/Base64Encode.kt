package benchmarks

import Benchmark
import java.util.Base64

class Base64Encode : Benchmark() {
    private var n: Long = 0
    private lateinit var str: String
    private lateinit var str2: String
    private var resultVal: UInt = 0u

    init {
        n = configVal("size")
    }

    override fun prepare() {
        str = "a".repeat(n.toInt())
        str2 = Base64.getEncoder().encodeToString(str.toByteArray())
    }

    override fun run(iterationId: Int) {

        val encoded = Base64.getEncoder().encodeToString(str.toByteArray())
        resultVal += encoded.length.toUInt()  
    }

    override fun checksum(): UInt {
        val message = "encode ${str.take(4)}... to ${str2.take(4)}...: $resultVal"
        return Helper.checksum(message)
    }

    override fun name(): String = "Base64Encode"
}