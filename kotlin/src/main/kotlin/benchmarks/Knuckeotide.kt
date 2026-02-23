package benchmarks

import Benchmark

class Knuckeotide : Benchmark() {
    private lateinit var seq: String
    private lateinit var output: StringBuilder

    override fun prepare() {
        output = StringBuilder()

        val fasta = Fasta()
        fasta.n = configVal("n")
        fasta.prepare()
        fasta.run(0)
        val res = fasta.getOutput()

        var three = false
        val seqio = StringBuilder()

        res.lineSequence().forEach { line ->
            if (line.startsWith(">THREE")) {
                three = true
                return@forEach
            }
            if (three) {
                seqio.append(line.trim())
            }
        }

        seq = seqio.toString()
    }

    private fun frequency(
        seq: String,
        length: Int,
    ): Pair<Int, Map<String, Int>> {
        val n = seq.length - length + 1
        val table = mutableMapOf<String, Int>()

        for (f in 0 until n) {
            val sub = seq.substring(f, f + length)
            table[sub] = table.getOrDefault(sub, 0) + 1
        }

        return Pair(n, table)
    }

    private fun sortByFreq(
        seq: String,
        length: Int,
    ) {
        val (n, table) = frequency(seq, length)

        table
            .toList()
            .sortedWith(
                compareByDescending<Pair<String, Int>> { it.second }
                    .thenBy { it.first },
            ).forEach { (key, value) ->
                val freq = (value * 100).toDouble() / n
                output.append(String.format("%s %.3f\n", key.uppercase(), freq))
            }

        output.append('\n')
    }

    private fun findSeq(
        seq: String,
        s: String,
    ) {
        val (n, table) = frequency(seq, s.length)
        output.append("${table.getOrDefault(s, 0)}\t${s.uppercase()}\n")
    }

    override fun run(iterationId: Int) {
        for (i in 1..2) {
            sortByFreq(seq, i)
        }

        listOf("ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt").forEach { s ->
            findSeq(seq, s)
        }
    }

    override fun checksum(): UInt = Helper.checksum(output.toString())

    override fun name(): String = "CLBG::Knuckeotide"
}
