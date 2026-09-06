package benchmarks

import Benchmark
import com.alibaba.fastjson2.JSONObject

class JsonParseDom : Benchmark() {
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
        val json = JSONObject.parseObject(text)
        val coordinates = json.getJSONArray("coordinates")

        var x = 0.0
        var y = 0.0
        var z = 0.0

        for (i in 0 until coordinates.size) {
            val coord = coordinates.getJSONObject(i)
            x += coord.getDoubleValue("x")
            y += coord.getDoubleValue("y")
            z += coord.getDoubleValue("z")
        }

        val len = coordinates.size.toDouble()
        return Coord(x / len, y / len, z / len)
    }

    override fun run(iterationId: Int) {
        val coord = calc(text)
        resultVal += Helper.checksumF64(coord.x) + Helper.checksumF64(coord.y) + Helper.checksumF64(coord.z)
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "Json::ParseDom"
}
