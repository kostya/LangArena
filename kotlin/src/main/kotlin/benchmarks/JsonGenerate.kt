package benchmarks

import Benchmark
import com.alibaba.fastjson2.JSONArray
import com.alibaba.fastjson2.JSONObject
import java.util.Locale

class JsonGenerate : Benchmark() {
    var n: Long = 0
    private lateinit var data: List<Map<String, Any>>
    public lateinit var text: String
    private var resultVal: Long = 0

    init {
        n = configVal("coords")
    }

    override fun prepare() {
        data = List(n.toInt()) {
            mapOf(
                "x" to String.format(Locale.US, "%.8f", Helper.nextFloat()).toDouble(),
                "y" to String.format(Locale.US, "%.8f", Helper.nextFloat()).toDouble(),
                "z" to String.format(Locale.US, "%.8f", Helper.nextFloat()).toDouble(),
                "name" to "${String.format(Locale.US, "%.7f", Helper.nextFloat())} ${Helper.nextInt(10000)}",
                "opts" to mapOf("1" to listOf(1, true))
            )
        }
    }

    override fun run(iterationId: Int) {
        val jsonArray = JSONArray()
        for (coord in data) {
            jsonArray.add(coord)
        }

        val jsonObject = JSONObject()
        jsonObject.put("coordinates", jsonArray)
        jsonObject.put("info", "some info")

        text = jsonObject.toJSONString() 
        if (text.startsWith("{\"coordinates\":")) resultVal += 1
    }

    override fun checksum(): UInt {
        return resultVal.toUInt()
    }

    override fun name(): String = "JsonGenerate"
}