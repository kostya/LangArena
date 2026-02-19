package benchmarks

class Fannkuchredux extends Benchmark:
  private val n: Int = configVal("n").toInt
  private var resultVal: Long = 0L

  override def name(): String = "Fannkuchredux"

  private case class Result(checksum: Int, maxFlips: Int)

  private def fannkuchredux(n: Int): Result =
    val perm1 = new Array[Int](32)
    val perm = new Array[Int](32)
    val count = new Array[Int](32)

    for i <- 0 until n do perm1(i) = i

    var maxFlipsCount = 0
    var permCount = 0
    var checksum = 0
    var r = n

    while true do
      while r > 1 do
        count(r - 1) = r
        r -= 1

      Array.copy(perm1, 0, perm, 0, n)

      var flipsCount = 0
      var k = perm(0)

      while k != 0 do
        val k2 = (k + 1) >> 1
        var i = 0
        while i < k2 do
          val j = k - i
          val temp = perm(i)
          perm(i) = perm(j)
          perm(j) = temp
          i += 1
        flipsCount += 1
        k = perm(0)

      if flipsCount > maxFlipsCount then maxFlipsCount = flipsCount

      if (permCount & 1) == 0 then checksum += flipsCount
      else checksum -= flipsCount

      var continueLoop = true
      while continueLoop do
        if r == n then return Result(checksum, maxFlipsCount)

        val perm0 = perm1(0)
        var i = 0
        while i < r do
          perm1(i) = perm1(i + 1)
          i += 1
        perm1(r) = perm0

        count(r) -= 1
        val cntr = count(r)
        if cntr > 0 then continueLoop = false
        else r += 1

      permCount += 1
    Result(checksum, maxFlipsCount)

  override def run(iterationId: Int): Unit =
    val res = fannkuchredux(n)
    resultVal += (res.checksum * 100L + res.maxFlips) & 0xffffffffL

  override def checksum(): Long = resultVal
