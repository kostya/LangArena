import java.io.IOException
import java.nio.file.Files
import java.nio.file.Paths
import java.util.*
import java.util.function.Supplier
import org.json.JSONObject

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
        return (last / IM.toDouble() * max).toInt()
    }

    fun nextInt(from: Int, to: Int): Int {
        return nextInt(to - from + 1) + from
    }

    fun nextFloat(max: Double = 1.0): Double {
        last = (last * IA + IC) % IM
        return max * last / IM.toDouble()
    }

    fun debug(message: Supplier<String>) {
        if ("1" == System.getenv("DEBUG")) {
            println(message.get())
        }
    }

    fun checksum(v: String): UInt {
        var hash: Long = 5381L
        v.forEach { char ->
            hash = ((hash shl 5) + hash) + char.code.toLong()
        }
        return (hash and 0xFFFFFFFFL).toUInt()
    }

    fun checksum(v: ByteArray): UInt {
        var hash: Long = 5381L
        v.forEach { byte ->
            hash = ((hash shl 5) + hash) + (byte.toInt() and 0xFF).toLong()
        }
        return (hash and 0xFFFFFFFFL).toUInt()
    }

    fun checksumF64(v: Double): UInt {
        return checksum(String.format(Locale.US, "%.7f", v)) and 0xFFFFFFFFu
    }

    var CONFIG = JSONObject()

    @Throws(IOException::class)
    fun loadConfig(filename: String? = null) {
        val file = filename ?: "../test.js"
        val content = String(Files.readAllBytes(Paths.get(file)))
        CONFIG = JSONObject(content)
    }

    fun configI64(className: String, fieldName: String): Long {
        return try {
            if (CONFIG.has(className) && CONFIG.getJSONObject(className).has(fieldName)) {
                CONFIG.getJSONObject(className).getLong(fieldName)
            } else {
                throw RuntimeException("Config not found for $className, field: $fieldName")
            }
        } catch (e: Exception) {
            System.err.println(e.message)
            0
        }
    }

    fun configS(className: String, fieldName: String): String {
        return try {
            if (CONFIG.has(className) && CONFIG.getJSONObject(className).has(fieldName)) {
                CONFIG.getJSONObject(className).getString(fieldName)
            } else {
                throw RuntimeException("Config not found for $className, field: $fieldName")
            }
        } catch (e: Exception) {
            System.err.println(e.message)
            ""
        }
    }

    private fun inspect(str: String): String {
        val sb = StringBuilder("\"")
        for (c in str.toCharArray()) {
            when (c) {
                '\n' -> sb.append("\\n")
                '\r' -> sb.append("\\r")
                '\t' -> sb.append("\\t")
                '\\' -> sb.append("\\\\")
                '\"' -> sb.append("\\\"")
                in ' '..'~' -> sb.append(c)
                else -> sb.append(String.format("\\u%04x", c.code))
            }
        }
        sb.append("\"")
        return sb.toString()
    }
}