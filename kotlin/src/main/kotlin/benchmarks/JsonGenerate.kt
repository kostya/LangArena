package benchmarks

import Benchmark
import com.alibaba.fastjson2.JSONArray
import com.alibaba.fastjson2.JSONObject
import java.util.Locale

class JsonGenerate : Benchmark() {
    var n = configVal("coords")
    private lateinit var data: List<Map<String, Any>>
    lateinit var text: String
    private var resultVal: Long = 0

    override fun prepare() {
        data =
            List(n.toInt()) {
                mapOf(
                    "x" to "%.8f".format(Locale.US, Helper.nextFloat()).toDouble(),
                    "y" to "%.8f".format(Locale.US, Helper.nextFloat()).toDouble(),
                    "z" to "%.8f".format(Locale.US, Helper.nextFloat()).toDouble(),
                    "name" to "${"%.7f".format(Locale.US, Helper.nextFloat())} ${Helper.nextInt(10000)}",
                    "opts" to mapOf("1" to listOf(1, true)),
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

    override fun checksum(): UInt = resultVal.toUInt()

    override fun name(): String = "Json::Generate"
}
