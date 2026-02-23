package benchmarks

import java.util.concurrent.{ForkJoinPool, RecursiveAction}

abstract class MatmulBase(threads: Int) extends Benchmark:
  protected var n: Int = 0
  protected var resultVal: Long = 0L
  protected var pool: ForkJoinPool = _
  protected var a: Array[Array[Double]] = _
  protected var b: Array[Array[Double]] = _

  private class RangeTask(start: Int, end: Int, action: Int => Unit) extends RecursiveAction:
    val THRESHOLD = 32

    override def compute(): Unit =
      if end - start <= THRESHOLD then
        var i = start
        while i < end do
          action(i)
          i += 1
      else
        val mid = (start + end) >>> 1
        val left = RangeTask(start, mid, action)
        val right = RangeTask(mid, end, action)
        left.fork()
        right.compute()
        left.join()

  protected def matgen(n: Int): Array[Array[Double]] =
    val tmp = 1.0 / n / n
    val a = Array.ofDim[Double](n, n)

    val task = RangeTask(
      0,
      n,
      i =>
        var j = 0
        while j < n do
          a(i)(j) = tmp * (i - j) * (i + j)
          j += 1
    )
    pool.invoke(task)
    a

  protected def transpose(b: Array[Array[Double]]): Array[Array[Double]] =
    val n = b.length
    val bT = Array.ofDim[Double](n, n)

    val task = RangeTask(
      0,
      n,
      i =>
        var j = 0
        while j < n do
          bT(j)(i) = b(i)(j)
          j += 1
    )
    pool.invoke(task)
    bT

  protected def matmulSequential(a: Array[Array[Double]], b: Array[Array[Double]]): Array[Array[Double]] =
    val n = a.length
    val p = b(0).length
    val b2 = Array.ofDim[Double](n, p)

    var i = 0
    while i < n do
      var j = 0
      while j < p do
        b2(j)(i) = b(i)(j)
        j += 1
      i += 1

    val c = Array.ofDim[Double](n, p)
    i = 0
    while i < n do
      val ci = c(i)
      val ai = a(i)
      var j = 0
      while j < p do
        var s = 0.0
        val b2j = b2(j)
        var k = 0
        while k < n do
          s += ai(k) * b2j(k)
          k += 1
        ci(j) = s
        j += 1
      i += 1
    c

  protected def matmulParallel(a: Array[Array[Double]], b: Array[Array[Double]]): Array[Array[Double]] =
    val n = a.length
    val bT = transpose(b)
    val c = Array.ofDim[Double](n, n)

    val mulTask = RangeTask(
      0,
      n,
      i =>
        val ai = a(i)
        var j = 0
        while j < n do
          var sum = 0.0
          val bTj = bT(j)
          var k = 0

          while k < n do
            sum += ai(k) * bTj(k)
            k += 1
          c(i)(j) = sum
          j += 1
    )
    pool.invoke(mulTask)
    c

  override def prepare(): Unit =
    n = configVal("n").toInt
    pool = new ForkJoinPool(threads)
    a = matgen(n)
    b = matgen(n)
    resultVal = 0L

  override def checksum(): Long = resultVal

  override def finalize(): Unit =
    try if pool != null then pool.shutdown()
    finally super.finalize()

class Matmul1T extends Benchmark:
  private var n: Int = 0
  private var resultVal: Long = 0L
  private var a: Array[Array[Double]] = _
  private var b: Array[Array[Double]] = _

  override def name(): String = "Matmul::Single"

  override def prepare(): Unit =
    n = configVal("n").toInt
    a = matgen(n)
    b = matgen(n)
    resultVal = 0L

  private def matgen(n: Int): Array[Array[Double]] =
    val tmp = 1.0 / n / n
    val a = Array.ofDim[Double](n, n)
    var i = 0
    while i < n do
      var j = 0
      while j < n do
        a(i)(j) = tmp * (i - j) * (i + j)
        j += 1
      i += 1
    a

  private def matmul(a: Array[Array[Double]], b: Array[Array[Double]]): Array[Array[Double]] =
    val n = a.length
    val b2 = Array.ofDim[Double](n, n)

    var i = 0
    while i < n do
      var j = 0
      while j < n do
        b2(j)(i) = b(i)(j)
        j += 1
      i += 1

    val c = Array.ofDim[Double](n, n)
    i = 0
    while i < n do
      val ci = c(i)
      val ai = a(i)
      var j = 0
      while j < n do
        var s = 0.0
        val b2j = b2(j)
        var k = 0

        while k < n do
          s += ai(k) * b2j(k)
          k += 1
        ci(j) = s
        j += 1
      i += 1
    c

  override def run(iterationId: Int): Unit =
    val c = matmul(a, b)
    resultVal += Helper.checksumF64(c(n >> 1)(n >> 1))

  override def checksum(): Long = resultVal

class Matmul4T extends MatmulBase(4):
  override def name(): String = "Matmul::T4"

  override def run(iterationId: Int): Unit =
    val c = matmulParallel(a, b)
    resultVal += Helper.checksumF64(c(n >> 1)(n >> 1))

class Matmul8T extends MatmulBase(8):
  override def name(): String = "Matmul::T8"

  override def run(iterationId: Int): Unit =
    val c = matmulParallel(a, b)
    resultVal += Helper.checksumF64(c(n >> 1)(n >> 1))

class Matmul16T extends MatmulBase(16):
  override def name(): String = "Matmul::T16"

  override def run(iterationId: Int): Unit =
    val c = matmulParallel(a, b)
    resultVal += Helper.checksumF64(c(n >> 1)(n >> 1))
