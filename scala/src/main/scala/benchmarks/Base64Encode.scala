package benchmarks

import java.util.Base64

class Base64Encode extends Benchmark:
  private var n: Long = 0
  private var str: String = _
  private var str2: String = _
  private var resultVal: Long = 0L

  override def name(): String = "Base64Encode"

  override def prepare(): Unit =
    n = configVal("size")
    str = "a" * n.toInt
    str2 = Base64.getEncoder.encodeToString(str.getBytes)

  override def run(iterationId: Int): Unit =
    val encoded = Base64.getEncoder.encodeToString(str.getBytes)
    resultVal += encoded.length.toLong

  override def checksum(): Long =
    val message = s"encode ${str.take(4)}... to ${str2.take(4)}...: $resultVal"
    Helper.checksum(message)