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
        text = generator.text
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