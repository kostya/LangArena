package benchmarks

import java.util.Base64

class Base64Decode extends Benchmark:
  private var n: Long = 0
  private var str2: String = _
  private var str3: String = _
  private var resultVal: Long = 0L

  override def name(): String = "Base64Decode"

  override def prepare(): Unit =
    n = configVal("size")
    val str = "a" * n.toInt
    str2 = Base64.getEncoder.encodeToString(str.getBytes)
    str3 = String(Base64.getDecoder.decode(str2))

  override def run(iterationId: Int): Unit =
    val decoded = String(Base64.getDecoder.decode(str2))
    resultVal += decoded.length.toLong

  override def checksum(): Long =
    val message = s"decode ${str2.take(4)}... to ${str3.take(4)}...: $resultVal"
    Helper.checksum(message)