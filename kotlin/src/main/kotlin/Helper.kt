import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Locale

object Helper {
    private const val IM = 139968
    private const val IA = 3877
    private const val IC = 29573
    private const val INIT = 42

    private var last = INIT

    var order: List<String> = emptyList()
        private set

    var config = JSONObject()
        private set

    fun reset() {
        last = INIT
    }

    fun nextInt(max: Int): Int {
        last = (last * IA + IC) % IM
        return (last / IM.toDouble() * max).toInt()
    }

    fun nextInt(
        from: Int,
        to: Int,
    ): Int = nextInt(to - from + 1) + from

    fun nextFloat(max: Double = 1.0): Double {
        last = (last * IA + IC) % IM
        return max * last / IM.toDouble()
    }

    fun debug(message: () -> String) {
        if ("1" == System.getenv("DEBUG")) {
            println(message())
        }
    }

    fun checksum(v: String): UInt {
        var hash = 5381L
        for (c in v) {
            hash = ((hash shl 5) + hash) + c.code
        }
        return hash.toUInt()
    }

    fun checksum(v: ByteArray): UInt {
        var hash = 5381L
        for (b in v) {
            hash = ((hash shl 5) + hash) + (b.toInt() and 0xFF)
        }
        return hash.toUInt()
    }

    fun checksumF64(v: Double): UInt = checksum("%.7f".format(Locale.US, v))

    fun loadConfig(filename: String? = null) {
        val jsonArray = JSONArray(File(filename ?: "../run.js").readText())
        val dict = JSONObject()
        val orderList = mutableListOf<String>()

        for (i in 0 until jsonArray.length()) {
            val item = jsonArray.getJSONObject(i)
            val name = item.getString("name")
            dict.put(name, item)
            orderList.add(name)
        }

        config = dict
        order = orderList
    }

    private fun configSection(
        className: String,
        fieldName: String,
    ): JSONObject? = config.optJSONObject(className)?.takeIf { it.has(fieldName) }

    fun optConfigI64(
        className: String,
        fieldName: String,
    ): Long? = configSection(className, fieldName)?.getLong(fieldName)

    fun configI64(
        className: String,
        fieldName: String,
    ): Long {
        val section = configSection(className, fieldName)
        if (section == null) {
            System.err.println("Config not found for $className, field: $fieldName")
            return 0
        }
        return section.getLong(fieldName)
    }

    fun configS(
        className: String,
        fieldName: String,
    ): String {
        val section = configSection(className, fieldName)
        if (section == null) {
            System.err.println("Config not found for $className, field: $fieldName")
            return ""
        }
        return section.getString(fieldName)
    }
}
