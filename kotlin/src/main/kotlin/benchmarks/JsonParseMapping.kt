package benchmarks

import Benchmark
import org.json.JSONArray
import org.json.JSONObject

data class Coord(val x: Double, val y: Double, val z: Double)

class JsonParseMapping : Benchmark() {
    private lateinit var text: String
    private var resultVal: UInt = 0u

    override fun prepare() {
        val generator = JsonGenerate()
        generator.n = configVal("coords")
        generator.prepare()
        generator.run(0)

        val dataField = generator::class.java.getDeclaredField("data")
        dataField.isAccessible = true
        val data = dataField.get(generator) as List<Map<String, Any>>

        val jsonArray = JSONArray()
        for (coord in data) {
            val obj = JSONObject()
            obj.put("x", coord["x"])
            obj.put("y", coord["y"])
            obj.put("z", coord["z"])
            jsonArray.put(obj)
        }

        val jsonObject = JSONObject()
        jsonObject.put("coordinates", jsonArray)
        text = jsonObject.toString()
    }

    private fun calc(text: String): Coord {
        val json = JSONObject(text)
        val coordinates = json.getJSONArray("coordinates")

        var x = 0.0
        var y = 0.0
        var z = 0.0

        for (i in 0 until coordinates.length()) {
            val coord = coordinates.getJSONObject(i)
            x += coord.getDouble("x")
            y += coord.getDouble("y")
            z += coord.getDouble("z")
        }

        val len = coordinates.length().toDouble()
        return Coord(x / len, y / len, z / len)
    }

    override fun run(iterationId: Int) {
        val coord = calc(text)
        resultVal += Helper.checksum("%.7f".format(coord.x)) +
                    Helper.checksum("%.7f".format(coord.y)) +
                    Helper.checksum("%.7f".format(coord.z))  
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "JsonParseMapping"
}