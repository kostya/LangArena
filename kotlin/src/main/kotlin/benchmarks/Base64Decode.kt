package benchmarks

import Benchmark
import java.util.Base64

class Base64Decode : Benchmark() {
    companion object {
        private const val TRIES = 8192
    }

    private var n: Int = 0
    private lateinit var str2: String
    private lateinit var str3: String
    private var _result: UInt = 0u  // переименовано

    init {
        n = iterations
    }

    override fun prepare() {
        val str = "a".repeat(n)
        str2 = Base64.getEncoder().encodeToString(str.toByteArray())
        str3 = String(Base64.getDecoder().decode(str2))
    }

    override fun run() {
        var sDecoded: Long = 0L

        repeat(TRIES) {
            val decoded = String(Base64.getDecoder().decode(str2))
            sDecoded += decoded.length.toLong()
        }

        val message = "decode ${str2.take(4)}... to ${str3.take(4)}...: $sDecoded\n"
        _result = Helper.checksum(message)
    }

    override val result: Long
        get() = _result.toLong()
}