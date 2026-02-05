package benchmarks

import Benchmark
import kotlin.text.Regex

class RegexDna : Benchmark() {
    private lateinit var seq: String
    private var ilen: Int = 0
    private var clen: Int = 0
    private lateinit var output: StringBuilder

    override fun prepare() {
        output = StringBuilder()

        val fasta = Fasta()
        fasta.n = configVal("n")
        fasta.prepare()
        fasta.run(0)
        val res = fasta.getOutput()

        val seqBuilder = StringBuilder()

        ilen = res.toByteArray(Charsets.UTF_8).size

        clen = 0
        val lines = res.split("\n")
        for (line in lines) {
            if (line.isNotEmpty() && !line.startsWith('>')) {
                seqBuilder.append(line)
                clen += line.toByteArray(Charsets.UTF_8).size
            }
        }

        seq = seqBuilder.toString()
    }

    override fun run(iterationId: Int) {
        val patterns = listOf(
            Regex("agggtaaa|tttaccct"),
            Regex("[cgt]gggtaaa|tttaccc[acg]"),
            Regex("a[act]ggtaaa|tttacc[agt]t"),
            Regex("ag[act]gtaaa|tttac[agt]ct"),
            Regex("agg[act]taaa|ttta[agt]cct"),
            Regex("aggg[acg]aaa|ttt[cgt]ccct"),
            Regex("agggt[cgt]aa|tt[acg]accct"),
            Regex("agggta[cgt]a|t[acg]taccct"),
            Regex("agggtaa[cgt]|[acg]ttaccct")
        )

        patterns.forEach { regex ->
            val count = regex.findAll(seq).count()
            output.append("${regex.pattern} $count\n")
        }

        val replacements = mapOf(
            "B" to "(c|g|t)",
            "D" to "(a|g|t)",
            "H" to "(a|c|t)",
            "K" to "(g|t)",
            "M" to "(a|c)",
            "N" to "(a|c|g|t)",
            "R" to "(a|g)",
            "S" to "(c|t)",
            "V" to "(a|c|g)",
            "W" to "(a|t)",
            "Y" to "(c|t)"
        )

        var processed = seq
        replacements.forEach { (key, value) ->
            processed = processed.replace(Regex(key), value)
        }

        output.append("\n")
        output.append("$ilen\n")
        output.append("$clen\n")
        output.append("${processed.length}\n")
    }

    override fun checksum(): UInt = Helper.checksum(output.toString())

    override fun name(): String = "RegexDna"
}