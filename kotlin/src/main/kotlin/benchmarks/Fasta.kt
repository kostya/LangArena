package benchmarks

import Benchmark

class Fasta : Benchmark() {
    var n: Long = 0
    private lateinit var output: StringBuilder

    init {
        n = configVal("n")
    }

    override fun prepare() {
        output = StringBuilder()
    }

    companion object {
        private const val LINE_LENGTH = 60

        private val IUB =
            listOf(
                Pair('a', 0.27),
                Pair('c', 0.39),
                Pair('g', 0.51),
                Pair('t', 0.78),
                Pair('B', 0.8),
                Pair('D', 0.8200000000000001),
                Pair('H', 0.8400000000000001),
                Pair('K', 0.8600000000000001),
                Pair('M', 0.8800000000000001),
                Pair('N', 0.9000000000000001),
                Pair('R', 0.9200000000000002),
                Pair('S', 0.9400000000000002),
                Pair('V', 0.9600000000000002),
                Pair('W', 0.9800000000000002),
                Pair('Y', 1.0000000000000002),
            )

        private val HOMO =
            listOf(
                Pair('a', 0.302954942668),
                Pair('c', 0.5009432431601),
                Pair('g', 0.6984905497992),
                Pair('t', 1.0),
            )

        private const val ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"
    }

    private fun selectRandom(genelist: List<Pair<Char, Double>>): Char {
        val r = Helper.nextFloat()
        if (r < genelist[0].second) return genelist[0].first

        var lo = 0
        var hi = genelist.size - 1

        while (hi > lo + 1) {
            val i = (hi + lo) / 2
            if (r < genelist[i].second) {
                hi = i
            } else {
                lo = i
            }
        }
        return genelist[hi].first
    }

    private fun makeRandomFasta(
        id: String,
        desc: String,
        genelist: List<Pair<Char, Double>>,
        n: Int,
    ) {
        output.append(">$id $desc\n")

        var todo = n
        while (todo > 0) {
            val m = if (todo < LINE_LENGTH) todo else LINE_LENGTH
            val buffer = CharArray(m)
            for (i in 0 until m) {
                buffer[i] = selectRandom(genelist)
            }
            output.append(buffer)
            output.append('\n')
            todo -= LINE_LENGTH
        }
    }

    private fun makeRepeatFasta(
        id: String,
        desc: String,
        s: String,
        n: Int,
    ) {
        output.append(">$id $desc\n")

        var todo = n
        var k = 0
        val kn = s.length

        while (todo > 0) {
            var m = if (todo < LINE_LENGTH) todo else LINE_LENGTH

            while (m >= kn - k) {
                output.append(s.substring(k))
                m -= kn - k
                k = 0
            }

            output.append(s.substring(k, k + m))
            output.append('\n')
            k += m
            todo -= LINE_LENGTH
        }
    }

    override fun run(iterationId: Int) {
        makeRepeatFasta("ONE", "Homo sapiens alu", ALU, (n * 2).toInt())
        makeRandomFasta("TWO", "IUB ambiguity codes", IUB, (n * 3).toInt())
        makeRandomFasta("THREE", "Homo sapiens frequency", HOMO, (n * 5).toInt())
    }

    override fun checksum(): UInt = Helper.checksum(output.toString())

    override fun name(): String = "CLBG::Fasta"

    fun getOutput(): String = output.toString()
}
