package benchmarks

class Revcomp extends Benchmark:
  private val LOOKUP = new Array[Char](256)
  private var input: String = _
  private var resultVal: Long = 0L

  private def initLookup(): Unit =
    var i = 0
    while i < 256 do
      LOOKUP(i) = i.toChar
      i += 1

    val from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
    val to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"

    i = 0
    while i < from.length do
      LOOKUP(from.charAt(i)) = to.charAt(i)
      i += 1

  initLookup()

  override def name(): String = "Revcomp"

  override def prepare(): Unit =
    val fasta = new Fasta()
    fasta.n = configVal("n").toInt
    fasta.run(0)
    val fastaResult = fasta.getResultString

    val seq = new StringBuilder()
    var start = 0
    var end = fastaResult.indexOf('\n', start)

    while end != -1 do
      val line = fastaResult.substring(start, end)

      if line.startsWith(">") then seq.append("\n---\n")
      else seq.append(line)

      start = end + 1
      end = fastaResult.indexOf('\n', start)

    input = seq.toString()

  private def revcompString(seq: String): String =
    val length = seq.length
    val lines = (length + 59) / 60
    val result = new Array[Char](length + lines)
    var pos = 0

    var start = length
    while start > 0 do
      val chunkStart = math.max(start - 60, 0)
      val chunkSize = start - chunkStart

      var i = start - 1
      while i >= chunkStart do
        val c = seq.charAt(i)
        result(pos) = LOOKUP(c)
        pos += 1
        i -= 1

      result(pos) = '\n'
      pos += 1
      start = chunkStart

    if length % 60 == 0 && length > 0 then pos -= 1

    String(result, 0, pos)

  override def run(iterationId: Int): Unit =
    resultVal += Helper.checksum(revcompString(input))

  override def checksum(): Long = resultVal
