package benchmarks

import java.io.ByteArrayOutputStream
import java.util.Locale

class Fasta extends Benchmark:
  private var _n: Int = 0

  def n_=(value: Int): Unit = _n = value
  def n: Int = _n

  private val result = new ByteArrayOutputStream()
  private val LINE_LENGTH = 60

  override def name(): String = "Fasta"

  override def prepare(): Unit =
    _n = configVal("n").toInt

  private case class Gene(ch: Char, prob: Double)

  private val IUB = Array(
    Gene('a', 0.27),
    Gene('c', 0.39),
    Gene('g', 0.51),
    Gene('t', 0.78),
    Gene('B', 0.8),
    Gene('D', 0.8200000000000001),
    Gene('H', 0.8400000000000001),
    Gene('K', 0.8600000000000001),
    Gene('M', 0.8800000000000001),
    Gene('N', 0.9000000000000001),
    Gene('R', 0.9200000000000002),
    Gene('S', 0.9400000000000002),
    Gene('V', 0.9600000000000002),
    Gene('W', 0.9800000000000002),
    Gene('Y', 1.0000000000000002)
  )

  private val HOMO = Array(
    Gene('a', 0.302954942668),
    Gene('c', 0.5009432431601),
    Gene('g', 0.6984905497992),
    Gene('t', 1.0)
  )

  private val ALU =
    "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

  private def selectRandom(genelist: Array[Gene]): Char =
    val r = Helper.nextFloat()
    if r < genelist(0).prob then return genelist(0).ch

    var lo = 0
    var hi = genelist.length - 1

    while hi > lo + 1 do
      val i = (hi + lo) / 2
      if r < genelist(i).prob then hi = i
      else lo = i

    genelist(hi).ch

  private def makeRandomFasta(id: String, desc: String, genelist: Array[Gene], n: Int): Unit =
    result.write(s">$id $desc\n".getBytes)

    var todo = n
    val buffer = new Array[Char](LINE_LENGTH)

    while todo > 0 do
      val m = math.min(todo, LINE_LENGTH)
      var i = 0
      while i < m do
        buffer(i) = selectRandom(genelist)
        i += 1
      result.write(new String(buffer.take(m)).getBytes)
      result.write('\n'.toInt)
      todo -= LINE_LENGTH

  private def makeRepeatFasta(id: String, desc: String, s: String, n: Int): Unit =
    result.write(s">$id $desc\n".getBytes)

    var todo = n
    var k = 0
    val kn = s.length

    while todo > 0 do
      val m = math.min(todo, LINE_LENGTH)
      var remaining = m

      while remaining >= kn - k do
        result.write(s.substring(k).getBytes)
        remaining -= kn - k
        k = 0

      if remaining > 0 then
        result.write(s.substring(k, k + remaining).getBytes)
        k += remaining

      result.write('\n'.toInt)
      todo -= LINE_LENGTH

  override def run(iterationId: Int): Unit =
    makeRepeatFasta("ONE", "Homo sapiens alu", ALU, _n * 2)
    makeRandomFasta("TWO", "IUB ambiguity codes", IUB, _n * 3)
    makeRandomFasta("THREE", "Homo sapiens frequency", HOMO, _n * 5)

  override def checksum(): Long =
    Helper.checksum(result.toByteArray())

  def getResultString: String = result.toString()
