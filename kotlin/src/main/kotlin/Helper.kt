// Файл: src/main/kotlin/Helper.kt
// НЕ в пакете benchmarks!

object Helper {
    private const val IM = 139968
    private const val IA = 3877
    private const val IC = 29573
    private const val INIT = 42

    private var last = INIT

    fun reset() {
        last = INIT
    }

    fun nextInt(max: Int): Int {
        last = (last * IA + IC) % IM
        return ((last.toDouble() / IM) * max).toInt()
    }

    fun nextInt(from: Int, to: Int): Int {
        return nextInt(to - from + 1) + from
    }

    fun nextFloat(max: Double = 1.0): Double {
        last = (last * IA + IC) % IM
        return max * last.toDouble() / IM
    }

    fun debug(message: () -> String) {
        if (System.getenv("DEBUG") == "1") {
            println(message())
        }
    }

    fun checksum(v: String): UInt {
        // debug { "checksum: ${v.inspect()}" }
        var hash = 5381u
        v.forEach { char ->
            hash = ((hash shl 5) + hash) + char.code.toUInt()
        }
        return hash
    }

    fun checksum(v: ByteArray): UInt {
        // debug { "checksum: ${v.contentToString()}" }
        var hash = 5381u
        v.forEach { byte ->
            // Ключевое исправление: преобразуем знаковый Byte в беззнаковый
            val unsignedByte = (byte.toInt() and 0xFF).toUInt()
            hash = ((hash shl 5) + hash) + unsignedByte
        }
        return hash
    }

    fun checksumF64(v: Double): UInt {
        return checksum("%.7f".format(v))
    }

    val INPUT = mutableMapOf<String, String>()
    val EXPECT = mutableMapOf<String, Long>()

    fun loadConfig(filename: String? = null) {
        val file = filename ?: "../test.txt"
        val lines = java.io.File(file).readLines().filter { it.isNotEmpty() }
        
        lines.forEach { line ->
            val parts = line.split("|")
            if (parts.size == 3) {
                INPUT[parts[0]] = parts[1]
                EXPECT[parts[0]] = parts[2].toLong()
            }
        }
    }

    // Extension function for String inspection similar to Crystal's .inspect
    private fun String.inspect(): String {
        return this.map { char ->
            when (char) {
                '\n' -> "\\n"
                '\r' -> "\\r"
                '\t' -> "\\t"
                '\\' -> "\\\\"
                '\"' -> "\\\""
                in ' '..'~' -> char.toString()
                else -> "\\u%04x".format(char.code)
            }
        }.joinToString("", "\"", "\"")
    }
}