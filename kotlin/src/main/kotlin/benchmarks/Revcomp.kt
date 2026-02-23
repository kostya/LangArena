package benchmarks

import Benchmark

class Revcomp : Benchmark() {
    private lateinit var input: String
    private var resultVal: UInt = 0u

    companion object {
        private val LOOKUP =
            CharArray(256).apply {
                for (i in indices) this[i] = i.toChar()

                val from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
                val to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"

                for (i in from.indices) {
                    this[from[i].code] = to[i]
                }
            }
    }

    override fun name(): String = "CLBG::Revcomp"

    override fun prepare() {
        val fasta = Fasta()
        fasta.n = configVal("n")
        fasta.prepare()
        fasta.run(0)

        val fastaResult = fasta.getOutput()

        val seq = StringBuilder()
        var start = 0
        var end: Int

        while (fastaResult.indexOf('\n', start).also { end = it } != -1) {
            val line = fastaResult.substring(start, end)

            if (line.isNotEmpty() && line[0] == '>') {
                seq.append("\n---\n")
            } else {
                seq.append(line)
            }

            start = end + 1
        }

        input = seq.toString()
    }

    private fun revcompFast(seq: String): String {
        val length = seq.length
        val lines = (length + 59) / 60
        val result = CharArray(length + lines)
        var pos = 0

        var start = length
        while (start > 0) {
            val chunkStart = maxOf(start - 60, 0)

            for (i in start - 1 downTo chunkStart) {
                result[pos++] = LOOKUP[seq[i].code]
            }

            result[pos++] = '\n'
            start = chunkStart
        }

        if (length % 60 == 0 && length > 0) {
            pos--
        }

        return String(result, 0, pos)
    }

    override fun run(iterationId: Int) {
        resultVal += Helper.checksum(revcompFast(input))
    }

    override fun checksum(): UInt = resultVal
}
