package benchmarks

import scala.collection.mutable.ArrayBuffer
import java.util.regex.Pattern

class RegexDna extends Benchmark:
  private var seq: String = _
  private var ilen: Int = 0
  private var clen: Int = 0
  private val result = new StringBuilder()
  private val compiledPatterns = ArrayBuffer.empty[Pattern]

  override def name(): String = "RegexDna"

  override def prepare(): Unit =
    val fasta = new Fasta()
    fasta.n = configVal("n").toInt
    fasta.run(0)
    val res = fasta.getResultString

    val seqBuilder = new StringBuilder()
    ilen = 0
    clen = 0

    val lines = res.split("\n")
    var i = 0
    while i < lines.length do
      val line = lines(i)
      ilen += line.length() + 1
      if !line.startsWith(">") then
        val trimmed = line.trim
        seqBuilder.append(trimmed)
        clen += trimmed.length
      i += 1

    seq = seqBuilder.toString()

    val patterns = Array(
      "agggtaaa|tttaccct",
      "[cgt]gggtaaa|tttaccc[acg]",
      "a[act]ggtaaa|tttacc[agt]t",
      "ag[act]gtaaa|tttac[agt]ct",
      "agg[act]taaa|ttta[agt]cct",
      "aggg[acg]aaa|ttt[cgt]ccct",
      "agggt[cgt]aa|tt[acg]accct",
      "agggta[cgt]a|t[acg]taccct",
      "agggtaa[cgt]|[acg]ttaccct"
    )

    compiledPatterns.clear()
    i = 0
    while i < patterns.length do
      compiledPatterns += Pattern.compile(patterns(i))
      i += 1

  private def countPattern(patternIdx: Int): Int =
    val pattern = compiledPatterns(patternIdx)
    val matcher = pattern.matcher(seq)
    var count = 0
    while matcher.find() do count += 1
    count

  override def run(iterationId: Int): Unit =
    var i = 0
    while i < compiledPatterns.length do
      val count = countPattern(i)
      val pattern = compiledPatterns(i).pattern()
      result.append(pattern).append(" ").append(count).append("\n")
      i += 1

    val replacements = Map(
      "B" -> "(c|g|t)",
      "D" -> "(a|g|t)",
      "H" -> "(a|c|t)",
      "K" -> "(g|t)",
      "M" -> "(a|c)",
      "N" -> "(a|c|g|t)",
      "R" -> "(a|g)",
      "S" -> "(c|t)",
      "V" -> "(a|c|g)",
      "W" -> "(a|t)",
      "Y" -> "(c|t)"
    )

    var newSeq = seq
    replacements.foreach { (key, value) =>
      newSeq = newSeq.replaceAll(key, value)
    }

    result.append("\n")
    result.append(ilen).append("\n")
    result.append(clen).append("\n")
    result.append(newSeq.length).append("\n")

  override def checksum(): Long =
    Helper.checksum(result.toString())

  def getResultString: String = result.toString()
