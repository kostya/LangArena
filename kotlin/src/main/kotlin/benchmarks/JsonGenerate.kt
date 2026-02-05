package benchmarks

import Benchmark
import org.json.JSONArray
import org.json.JSONObject

class JsonGenerate : Benchmark() {
    var n: Long = 0
    private lateinit var data: List<Map<String, Any>>
    private lateinit var text: String
    private var resultVal: Long = 0

    init {
        n = configVal("coords")
    }

    override fun prepare() {
        data = List(n.toInt()) {
            mapOf(
                "x" to String.format("%.8f", Helper.nextFloat()).toDouble(),
                "y" to String.format("%.8f", Helper.nextFloat()).toDouble(),
                "z" to String.format("%.8f", Helper.nextFloat()).toDouble(),
                "name" to "${String.format("%.7f", Helper.nextFloat())} ${Helper.nextInt(10000)}",
                "opts" to mapOf("1" to listOf(1, true))
            )
        }
    }

    override fun run(iterationId: Int) {
        val jsonArray = JSONArray()
        for (coord in data) {
            jsonArray.put(coord)
        }

        val jsonObject = JSONObject()
        jsonObject.put("coordinates", jsonArray)
        jsonObject.put("info", "some info")

        text = jsonObject.toString()
        if (text.startsWith("{\"coordinates\":")) resultVal += 1
    }

    override fun checksum(): UInt {
        return resultVal.toUInt()
    }

    override fun name(): String = "JsonGenerate"
}