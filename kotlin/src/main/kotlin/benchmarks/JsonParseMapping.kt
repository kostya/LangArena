package benchmarks

import Benchmark
import com.alibaba.fastjson2.*

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

        val data = text.into<CoordinatesData>()
        val coordinates = data.coordinates

        var x = 0.0
        var y = 0.0
        var z = 0.0

        for (coord in coordinates) {
            x += coord.x
            y += coord.y
            z += coord.z
        }

        val len = coordinates.size.toDouble()
        return Coord(x / len, y / len, z / len)
    }

    class CoordinatesData {
        var coordinates: List<Coord> = emptyList()
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