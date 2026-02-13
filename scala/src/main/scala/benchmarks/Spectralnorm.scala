package benchmarks

class Spectralnorm extends Benchmark:
  private var sizeVal: Int = 0
  private var u: Array[Double] = _
  private var v: Array[Double] = _

  override def name(): String = "Spectralnorm"

  override def prepare(): Unit =
    sizeVal = configVal("size").toInt
    u = Array.fill(sizeVal)(1.0)
    v = Array.fill(sizeVal)(1.0)

  private def evalA(i: Int, j: Int): Double =
    1.0 / ((i + j) * (i + j + 1.0) / 2.0 + i + 1.0)

  private def evalATimesU(u: Array[Double]): Array[Double] =
    val result = new Array[Double](u.length)
    var i = 0
    while i < u.length do
      var sum = 0.0
      var j = 0
      while j < u.length do
        sum += evalA(i, j) * u(j)
        j += 1
      result(i) = sum
      i += 1
    result

  private def evalAtTimesU(u: Array[Double]): Array[Double] =
    val result = new Array[Double](u.length)
    var i = 0
    while i < u.length do
      var sum = 0.0
      var j = 0
      while j < u.length do
        sum += evalA(j, i) * u(j)
        j += 1
      result(i) = sum
      i += 1
    result

  private def evalAtATimesU(u: Array[Double]): Array[Double] =
    evalAtTimesU(evalATimesU(u))

  override def run(iterationId: Int): Unit =
    v = evalAtATimesU(u)
    u = evalAtATimesU(v)

  override def checksum(): Long =
    var vBv = 0.0
    var vv = 0.0
    var i = 0
    while i < sizeVal do
      vBv += u(i) * v(i)
      vv += v(i) * v(i)
      i += 1
    Helper.checksumF64(math.sqrt(vBv / vv))