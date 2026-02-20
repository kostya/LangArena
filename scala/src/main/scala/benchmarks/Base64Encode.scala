package benchmarks

import java.util.Base64

class Base64Encode extends Benchmark:
  private var n: Long = 0
  private var str: Array[Byte] = _
  private var str2: String = _
  private var resultVal: Long = 0L

  override def name(): String = "Base64Encode"

  override def prepare(): Unit =
    n = configVal("size")
    val _str = "a" * n.toInt
    str = _str.getBytes
    str2 = Base64.getEncoder.encodeToString(str)

  override def run(iterationId: Int): Unit =
    str2 = Base64.getEncoder.encodeToString(str)
    resultVal += str2.length.toLong

  override def checksum(): Long =
    val _str = new String(str.take(4), "UTF-8")
    val message = s"encode ${_str.take(4)}... to ${str2.take(4)}...: $resultVal"
    Helper.checksum(message)
