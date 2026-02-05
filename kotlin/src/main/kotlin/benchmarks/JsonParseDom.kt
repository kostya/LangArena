package benchmarks

import Benchmark
import org.json.JSONArray
import org.json.JSONObject

class JsonParseDom : Benchmark() {
    private lateinit var text: String
    private var resultVal: UInt = 0u

    override fun prepare() {
        val generator = JsonGenerate()
        generator.n = configVal("coords")
        generator.prepare()
        generator.run(0)

        val field = generator::class.java.getDeclaredField("text")
        field.isAccessible = true
        text = field.get(generator) as String
    }

    private fun calc(text: String): Triple<Double, Double, Double> {
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
        return Triple(x / len, y / len, z / len)
    }

    override fun run(iterationId: Int) {
        val (x, y, z) = calc(text)
        resultVal += Helper.checksum("%.7f".format(x)) +
                    Helper.checksum("%.7f".format(y)) +
                    Helper.checksum("%.7f".format(z))  
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "JsonParseDom"
}