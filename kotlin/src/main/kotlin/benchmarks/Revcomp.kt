package benchmarks

import Benchmark

class Revcomp : Benchmark() {
    private lateinit var input: String
    private lateinit var output: StringBuilder
    
    override fun prepare() {
        output = StringBuilder()
        
        val fasta = Fasta()
        fasta.n = iterations
        fasta.prepare()
        fasta.run()
        
        input = fasta.getOutput()
    }
    
    private fun revcomp(seq: String) {
        // Таблица трансляции как в Crystal
        val from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
        val to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"
        
        val translationMap = mutableMapOf<Char, Char>()
        for (i in from.indices) {
            translationMap[from[i]] = to[i]
        }
        
        val reversed = seq.reversed()
        val complemented = StringBuilder(reversed.length)
        
        for (ch in reversed) {
            complemented.append(translationMap[ch] ?: ch)
        }
        
        val result = complemented.toString()
        var i = 0
        while (i < result.length) {
            val end = minOf(i + 60, result.length)
            output.append(result.substring(i, end))
            output.append('\n')
            i += 60
        }
    }
        
    override fun run() {
        val seq = StringBuilder()
        
        input.lineSequence().forEach { line ->
            if (line.startsWith('>')) {
                if (seq.isNotEmpty()) {
                    revcomp(seq.toString())
                    seq.clear()
                }
                output.append(line)
                output.append('\n')
            } else {
                seq.append(line.trim())
            }
        }
        
        if (seq.isNotEmpty()) {
            revcomp(seq.toString())
        }
    }
    
    override val result: Long
        get() = Helper.checksum(output.toString()).toLong()
}