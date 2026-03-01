package benchmarks

import scala.collection.mutable

class Words extends Benchmark:
  private val CHARS = "abcdefghijklmnopqrstuvwxyz"

  private var words: Int = 0
  private var wordLen: Int = 0
  private var text: String = ""
  private var checksumVal: Long = 0L

  override def name(): String = "Etc::Words"

  override def prepare(): Unit =
    words = configVal("words").toInt
    wordLen = configVal("word_len").toInt

    val wordsList = mutable.ListBuffer.empty[String]

    for i <- 0 until words do
      val len = Helper.nextInt(wordLen) + Helper.nextInt(3) + 3
      val wordChars = new Array[Char](len)
      for j <- 0 until len do
        val idx = Helper.nextInt(CHARS.length)
        wordChars(j) = CHARS(idx)
      wordsList += new String(wordChars)

    text = wordsList.mkString(" ")

  override def run(iterationId: Int): Unit =

    val frequencies = mutable.Map.empty[String, Int].withDefaultValue(0)

    for word <- text.split(' ') do if word.nonEmpty then frequencies(word) += 1

    var maxWord = ""
    var maxCount = 0

    for (word, count) <- frequencies do
      if count > maxCount then
        maxCount = count
        maxWord = word

    val freqSize = frequencies.size.toLong
    val wordChecksum = Helper.checksum(maxWord)

    checksumVal += maxCount.toLong + wordChecksum + freqSize

  override def checksum(): Long = checksumVal
