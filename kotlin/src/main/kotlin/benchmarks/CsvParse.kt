package benchmarks

import Benchmark
import Helper
import com.opencsv.CSVReader
import java.io.StringReader
import java.util.Locale

class CsvParse : Benchmark() {
    private lateinit var data: String
    private var resultVal: UInt = 0u
    private val rows: Int by lazy { configVal("rows").toInt() }

    override fun name(): String = "CSV::Parse"

    override fun prepare() {
        val sb = StringBuilder(rows * 50)

        for (i in 0 until rows) {
            val c = ('A' + (i % 26)).toChar()
            val x = Helper.nextFloat()
            val z = Helper.nextFloat()
            val y = Helper.nextFloat()

            sb
                .append('"')
                .append("point ")
                .append(c)
                .append("\\n, \"\"")
                .append(i % 100)
                .append("\"\"\"")
                .append(',')

            sb.append(String.format(Locale.US, "%.10f", x)).append(',')

            sb.append(',')

            sb.append(String.format(Locale.US, "%.10f", z)).append(',')

            sb
                .append('"')
                .append('[')
                .append(if (i % 2 == 0) "true" else "false")
                .append("\\n, ")
                .append(i % 100)
                .append(']')
                .append('"')
                .append(',')

            sb.append(String.format(Locale.US, "%.10f", y)).append('\n')
        }

        data = sb.toString()
    }

    data class Point(
        val x: Double,
        val y: Double,
        val z: Double,
    )

    private fun parsePoints(csvData: String): List<Point> {
        val points = mutableListOf<Point>()

        CSVReader(StringReader(csvData)).use { reader ->
            var record: Array<String>? = reader.readNext()
            while (record != null) {
                val x = record[1].toDouble()
                val z = record[3].toDouble()
                val y = record[5].toDouble()
                points.add(Point(x, y, z))
                record = reader.readNext()
            }
        }

        return points
    }

    override fun run(iterationId: Int) {
        val points = parsePoints(data)

        if (points.isEmpty()) return

        var xSum = 0.0
        var ySum = 0.0
        var zSum = 0.0

        for (p in points) {
            xSum += p.x
            ySum += p.y
            zSum += p.z
        }

        val count = points.size.toDouble()
        val xAvg = xSum / count
        val yAvg = ySum / count
        val zAvg = zSum / count

        resultVal += Helper.checksum("%.7f".format(xAvg)) +
            Helper.checksum("%.7f".format(yAvg)) +
            Helper.checksum("%.7f".format(zAvg))
    }

    override fun checksum(): UInt = resultVal
}
