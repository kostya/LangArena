package benchmarks

import com.alibaba.fastjson2.{JSONArray, JSONObject}

class JsonParseDom extends Benchmark:
  private var text: String = _
  private var resultVal: Long = 0L

  override def name(): String = "JsonParseDom"

  override def prepare(): Unit =
    val generator = new JsonGenerate()
    generator.n = configVal("coords").toInt
    generator.prepare()
    generator.run(0)
    text = generator.getText
    resultVal = 0L

  private def calc(text: String): (Double, Double, Double) =
    val json = JSONObject.parseObject(text)
    val coordinates = json.getJSONArray("coordinates")

    var x = 0.0
    var y = 0.0
    var z = 0.0

    var i = 0
    while i < coordinates.size() do
      val coord = coordinates.getJSONObject(i)
      x += coord.getDouble("x")
      y += coord.getDouble("y")
      z += coord.getDouble("z")
      i += 1

    val len = coordinates.size()
    (x / len, y / len, z / len)

  override def run(iterationId: Int): Unit =
    val (x, y, z) = calc(text)

    val sum = (Helper.checksumF64(x) + Helper.checksumF64(y) + Helper.checksumF64(z)) & 0xffffffffL
    resultVal += sum

  override def checksum(): Long = resultVal & 0xffffffffL
