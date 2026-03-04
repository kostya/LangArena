package benchmarks

import com.opencsv.{CSVReader, CSVReaderBuilder}
import com.opencsv.exceptions.CsvException
import java.io.StringReader
import java.util.Locale
import scala.collection.mutable.ArrayBuffer
import scala.jdk.CollectionConverters.*

class CsvParse extends Benchmark {
  private var rows: Int = _
  private var data: String = _
  private var resultVal: Long = 0L

  override def name(): String = "CSV::Parse"

  override def prepare(): Unit = {
    rows = configVal("rows").toInt
    val sb = new StringBuilder(rows * 50)

    for (i <- 0 until rows) {
      val c = ('A' + (i % 26)).toChar
      val x = Helper.nextFloat()
      val z = Helper.nextFloat()
      val y = Helper.nextFloat()
      sb.append('"')
        .append("point ")
        .append(c)
        .append("\\n, \"\"")
        .append(i % 100)
        .append("\"\"\"")
        .append(',')
      sb.append(String.format(Locale.US, "%.10f", x)).append(',')
      sb.append(',')
      sb.append(String.format(Locale.US, "%.10f", z)).append(',')
      sb.append('"')
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
    resultVal = 0L
  }

  private case class Point(x: Double, y: Double, z: Double)

  private def parsePoints(csvData: String): Array[Point] = {
    val points = ArrayBuffer.empty[Point]

    val reader = new CSVReader(new StringReader(csvData))
    try {
      var record: Array[String] = reader.readNext()
      while (record != null) {
        val x = record(1).toDouble
        val z = record(3).toDouble
        val y = record(5).toDouble
        points += Point(x, y, z)
        record = reader.readNext()
      }
    } finally {
      reader.close()
    }

    points.toArray
  }

  override def run(iterationId: Int): Unit = {
    val points = parsePoints(data)

    if (points.length == 0) return

    var xSum = 0.0
    var ySum = 0.0
    var zSum = 0.0

    for (p <- points) {
      xSum += p.x
      ySum += p.y
      zSum += p.z
    }

    val len = points.length
    val xAvg = xSum / len
    val yAvg = ySum / len
    val zAvg = zSum / len

    resultVal += Helper.checksumF64(xAvg) + Helper.checksumF64(yAvg) + Helper.checksumF64(zAvg)
  }

  override def checksum(): Long = resultVal
}
