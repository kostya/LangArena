package benchmarks

import scala.collection.mutable

object Distance:
  case class StringPair(s1: String, s2: String)

  def generatePairStrings(n: Int, m: Int): Array[StringPair] =
    val chars = "abcdefghij".toCharArray
    val pairs = new Array[StringPair](n)

    for (i <- 0 until n) {
      val len1 = Helper.nextInt(m) + 4
      val len2 = Helper.nextInt(m) + 4

      val str1 = new StringBuilder(len1)
      val str2 = new StringBuilder(len2)

      for (_ <- 0 until len1) str1.append(chars(Helper.nextInt(10)))
      for (_ <- 0 until len2) str2.append(chars(Helper.nextInt(10)))

      pairs(i) = StringPair(str1.toString, str2.toString)
    }

    pairs

  class Jaro extends Benchmark:
    private var count: Int = 0
    private var size: Int = 0
    private var pairs: Array[StringPair] = _
    private var resultVal: Long = 0L

    override def name(): String = "Distance::Jaro"

    override def prepare(): Unit =
      count = configVal("count").toInt
      size = configVal("size").toInt
      pairs = Distance.generatePairStrings(count, size)
      resultVal = 0L

    private def jaro(s1: String, s2: String): Double =
      val bytes1 = s1.getBytes("US-ASCII")
      val bytes2 = s2.getBytes("US-ASCII")

      val len1 = bytes1.length
      val len2 = bytes2.length

      if len1 == 0 || len2 == 0 then return 0.0

      var matchDist = Math.max(len1, len2) / 2 - 1
      if matchDist < 0 then matchDist = 0

      val s1Matches = new Array[Boolean](len1)
      val s2Matches = new Array[Boolean](len2)

      var matches = 0
      for (i <- 0 until len1) {
        val start = Math.max(0, i - matchDist)
        val end = Math.min(len2 - 1, i + matchDist)

        var found = false
        var j = start
        while j <= end && !found do
          if (!s2Matches(j) && bytes1(i) == bytes2(j)) {
            s1Matches(i) = true
            s2Matches(j) = true
            matches += 1
            found = true
          }
          j += 1
      }

      if matches == 0 then return 0.0

      var transpositions = 0
      var k = 0
      for (i <- 0 until len1) {
        if (s1Matches(i)) {
          while (k < len2 && !s2Matches(k)) {
            k += 1
          }
          if (k < len2) {
            if (bytes1(i) != bytes2(k)) {
              transpositions += 1
            }
            k += 1
          }
        }
      }
      transpositions /= 2

      val m = matches.toDouble
      (m / len1 + m / len2 + (m - transpositions) / m) / 3.0

    override def run(iterationId: Int): Unit =
      for (pair <- pairs) {
        resultVal = (resultVal + (jaro(pair.s1, pair.s2) * 1000).toLong) & 0xffffffffL
      }

    override def checksum(): Long = resultVal & 0xffffffffL

  class NGram extends Benchmark:
    private var count: Int = 0
    private var size: Int = 0
    private var pairs: Array[StringPair] = _
    private var resultVal: Long = 0L
    private val N = 4

    override def name(): String = "Distance::NGram"

    override def prepare(): Unit =
      count = configVal("count").toInt
      size = configVal("size").toInt
      pairs = Distance.generatePairStrings(count, size)
      resultVal = 0L

    private def ngram(s1: String, s2: String): Double =
      val bytes1 = s1.getBytes("US-ASCII")
      val bytes2 = s2.getBytes("US-ASCII")

      if bytes1.length < N || bytes2.length < N then return 0.0

      val grams1 = new java.util.HashMap[Int, Int](bytes1.length)

      for (i <- 0 to bytes1.length - N) {
        val gram = (bytes1(i) & 0xff) << 24 |
          (bytes1(i + 1) & 0xff) << 16 |
          (bytes1(i + 2) & 0xff) << 8 |
          (bytes1(i + 3) & 0xff)

        grams1.merge(gram, 1, (a, b) => a + b)
      }

      val grams2 = new java.util.HashMap[Int, Int](bytes2.length)
      var intersection = 0

      for (i <- 0 to bytes2.length - N) {
        val gram = (bytes2(i) & 0xff) << 24 |
          (bytes2(i + 1) & 0xff) << 16 |
          (bytes2(i + 2) & 0xff) << 8 |
          (bytes2(i + 3) & 0xff)

        grams2.merge(gram, 1, (a, b) => a + b)

        if grams1.containsKey(gram) then
          val cnt1 = grams1.get(gram)
          if grams2.get(gram) <= cnt1 then intersection += 1
      }

      val total = grams1.size + grams2.size
      if total > 0 then intersection.toDouble / total else 0.0

    override def run(iterationId: Int): Unit =
      for (pair <- pairs) {
        resultVal = (resultVal + (ngram(pair.s1, pair.s2) * 1000).toLong) & 0xffffffffL
      }

    override def checksum(): Long = resultVal & 0xffffffffL
