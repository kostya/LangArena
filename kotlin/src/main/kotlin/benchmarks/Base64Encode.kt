package benchmarks

import Benchmark
import java.util.Base64

class Base64Encode : Benchmark() {
    companion object {
        private const val TRIES = 8192
    }

    private var n: Int = 0
    private lateinit var str: String
    private lateinit var str2: String
    private var _result: UInt = 0u  // переименовано

    init {
        n = iterations
    }

    override fun prepare() {
        str = "a".repeat(n)
        str2 = Base64.getEncoder().encodeToString(str.toByteArray())
    }

    override fun run() {
        var sEncoded: Long = 0L

        repeat(TRIES) {
            val encoded = Base64.getEncoder().encodeToString(str.toByteArray())
            sEncoded += encoded.length.toLong()
        }

        val message = "encode ${str.take(4)}... to ${str2.take(4)}...: $sEncoded\n"
        _result = Helper.checksum(message)
    }

    override val result: Long
        get() = _result.toLong()
}