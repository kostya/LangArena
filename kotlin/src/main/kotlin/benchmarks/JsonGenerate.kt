package benchmarks

import Benchmark
import org.json.JSONArray
import org.json.JSONObject

class JsonGenerate : Benchmark() {
    public var n: Int = 0
    private lateinit var data: List<Map<String, Any>>
    private var text: String = ""

    init {
        n = iterations
    }

    override fun prepare() {
        data = List(n) {
            mapOf(
                "x" to String.format("%.8f", Helper.nextFloat()).toDouble(),
                "y" to String.format("%.8f", Helper.nextFloat()).toDouble(),
                "z" to String.format("%.8f", Helper.nextFloat()).toDouble(),
                "name" to "${String.format("%.7f", Helper.nextFloat())} ${Helper.nextInt(10000)}",
                "opts" to mapOf("1" to listOf(1, true))
            )
        }
    }

    override fun run() {
        val jsonArray = JSONArray()
        for (coord in data) {
            jsonArray.put(coord)
        }
        
        val jsonObject = JSONObject()
        jsonObject.put("coordinates", jsonArray)
        jsonObject.put("info", "some info")
        
        text = jsonObject.toString()
    }

    override val result: Long
        get() = 1L
}