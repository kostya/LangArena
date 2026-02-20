package benchmarks

import java.io.ByteArrayOutputStream
import java.nio.charset.StandardCharsets
import java.util.{HashMap, Locale, ArrayList}
import scala.jdk.CollectionConverters.*

class Knuckeotide extends Benchmark {
  private var seq: String = _
  private val result = new ByteArrayOutputStream()
  private val NL = "\n"

  override def name(): String = "Knuckeotide"

  override def prepare(): Unit = {
    val fasta = new Fasta()
    fasta.n = configVal("n").toInt
    fasta.run(0)

    val fastaOutput = fasta.getResultString

    val seqBuilder = new StringBuilder()
    var afterThree = false

    val lines = fastaOutput.split("\n")
    var i = 0
    while (i < lines.length) {
      val line = lines(i)
      if (line.startsWith(">THREE")) {
        afterThree = true
      } else if (afterThree) {
        if (line.startsWith(">")) {
          i = lines.length
        } else {
          seqBuilder.append(line.trim())
        }
      }
      i += 1
    }

    seq = seqBuilder.toString()
  }

  private class FreqResult(val n: Int, val table: java.util.Map[String, Int])

  private def frequency(seq: String, length: Int): FreqResult = {
    val n = seq.length - length + 1
    if (n <= 0) return new FreqResult(0, new HashMap())

    val table = new HashMap[String, Int]()
    var i = 0
    while (i < n) {
      val sub = seq.substring(i, i + length)
      table.put(sub, table.getOrDefault(sub, 0) + 1)
      i += 1
    }

    new FreqResult(n, table)
  }

  private def sortByFreq(seq: String, length: Int): Unit = {
    val fr = frequency(seq, length)
    val entries = new ArrayList(fr.table.entrySet())

    entries.sort((a: java.util.Map.Entry[String, Int], b: java.util.Map.Entry[String, Int]) => {
      val cmp = b.getValue.compareTo(a.getValue)
      if (cmp != 0) cmp else a.getKey.compareTo(b.getKey)
    })

    val iter = entries.iterator
    while (iter.hasNext) {
      val entry = iter.next
      val freq = (entry.getValue * 100.0) / fr.n
      val line = String.format(Locale.US, "%s %.3f%s", entry.getKey.toUpperCase(Locale.US), freq, NL)
      result.write(line.getBytes(StandardCharsets.UTF_8))
    }

    result.write(NL.getBytes(StandardCharsets.UTF_8))
  }

  private def findSeq(seq: String, pattern: String): Unit = {
    val patternLower = pattern.toLowerCase(Locale.US)
    val fr = frequency(seq, patternLower.length)
    val count = fr.table.getOrDefault(patternLower, 0)
    val line = count + "\t" + pattern.toUpperCase(Locale.US) + NL
    result.write(line.getBytes(StandardCharsets.UTF_8))
  }

  override def run(iterationId: Int): Unit = {
    var i = 1
    while (i <= 2) {
      sortByFreq(seq, i)
      i += 1
    }

    val patterns = Array("ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt")
    i = 0
    while (i < patterns.length) {
      findSeq(seq, patterns(i))
      i += 1
    }
  }

  override def checksum(): Long = {
    val output = result.toString(StandardCharsets.UTF_8)
    Helper.checksum(output)
  }

  def getResultString: String = result.toString(StandardCharsets.UTF_8)
}
