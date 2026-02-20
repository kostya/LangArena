package benchmarks

import com.alibaba.fastjson2.JSON
import scala.jdk.CollectionConverters.*

class JsonParseMapping extends Benchmark:
  private var text: String = _
  private var resultVal: Long = 0L

  override def name(): String = "JsonParseMapping"

  override def prepare(): Unit =
    val generator = new JsonGenerate()
    generator.n = configVal("coords").toInt
    generator.prepare()
    generator.run(0)
    text = generator.getText
    resultVal = 0L

  override def run(iterationId: Int): Unit =
    val data = JSON.parseObject(text, classOf[CoordinatesData])
    val coords = data.coordinates.asScala

    var x = 0.0
    var y = 0.0
    var z = 0.0

    coords.foreach { c =>
      x += c.x
      y += c.y
      z += c.z
    }

    val len = coords.size.toDouble
    val checksum = (
      Helper.checksumF64(x / len).toInt +
        Helper.checksumF64(y / len).toInt +
        Helper.checksumF64(z / len).toInt
    ) & 0xffffffffL

    resultVal += checksum

  override def checksum(): Long = resultVal & 0xffffffffL
