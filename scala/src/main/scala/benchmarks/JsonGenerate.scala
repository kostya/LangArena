package benchmarks

import com.alibaba.fastjson2.{JSONArray, JSONObject}
import scala.collection.mutable
import java.util.Locale

class JsonGenerate extends Benchmark:
  private var _n: Int = Helper.configI64("JsonGenerate", "coords").toInt

  def n: Int = _n
  def n_=(value: Int): Unit = _n = value  

  private val data = mutable.ArrayBuffer.empty[mutable.LinkedHashMap[String, Any]]
  private var text: String = ""
  private var resultVal: Long = 0L

  override def name(): String = "JsonGenerate"

  override def prepare(): Unit =
    data.clear()

    var i = 0
    while i < n do
      val coord = mutable.LinkedHashMap.empty[String, Any]

      coord("x") = math.round(Helper.nextFloat() * 1e8) / 1e8
      coord("y") = math.round(Helper.nextFloat() * 1e8) / 1e8
      coord("z") = math.round(Helper.nextFloat() * 1e8) / 1e8

      coord("name") = String.format(Locale.US, "%.7f %d", 
        Helper.nextFloat(), Helper.nextInt(10000))

      val opts = mutable.LinkedHashMap.empty[String, mutable.ArrayBuffer[Any]]
      val tuple = mutable.ArrayBuffer.empty[Any]
      tuple += 1
      tuple += true
      opts("1") = tuple
      coord("opts") = opts

      data += coord
      i += 1

  override def run(iterationId: Int): Unit =
    val jsonArray = new JSONArray()
    data.foreach { coord =>
      val jsonCoord = new JSONObject()
      coord.foreach { (key, value) =>
        jsonCoord.put(key, value)
      }
      jsonArray.add(jsonCoord)
    }

    val jsonObject = new JSONObject()
    jsonObject.put("coordinates", jsonArray)
    jsonObject.put("info", "some info")

    text = jsonObject.toString()
    if text.startsWith("{\"coordinates\":") then resultVal += 1

  override def checksum(): Long = resultVal

  def getText: String = text