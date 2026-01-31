package benchmarks

import Benchmark

class Revcomp : Benchmark() {
    private lateinit var input: String
    private var resultVal: UInt = 0u
    
    companion object {
        private val LOOKUP = CharArray(256).apply {
            // Инициализируем как идентичное преобразование
            for (i in indices) {
                this[i] = i.toChar()
            }
            
            val from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
            val to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"
            
            for (i in from.indices) {
                this[from[i].code] = to[i]
            }
        }
    }
    
    override fun name(): String = "Revcomp"
    
    override fun prepare() {
        val fasta = Fasta()
        fasta.n = configVal("n")  // Без .toInt(), т.к. n в Fasta имеет тип Long
        fasta.prepare()
        fasta.run(0)
        
        val fastaResult = fasta.getOutput()
        
        // Обрабатываем как в C++ версии
        val seq = StringBuilder()
        fastaResult.lineSequence().forEach { line: String ->
            if (line.isNotEmpty() && line[0] == '>') {
                seq.append("\n---\n")
            } else {
                seq.append(line)
            }
        }
        
        input = seq.toString()
    }
    
    private fun revcomp(seq: String): String {
        val reversed = seq.reversed()
        val complemented = CharArray(reversed.length)
        
        for (i in reversed.indices) {
            complemented[i] = LOOKUP[reversed[i].code]
        }
        
        val result = StringBuilder()
        for (i in complemented.indices step 60) {
            val end = minOf(i + 60, complemented.size)
            result.append(complemented, i, end - i)
            result.append('\n')
        }
        
        return result.toString()
    }
    
    override fun run(iterationId: Int) {
        resultVal += Helper.checksum(revcomp(input))
    }
    
    override fun checksum(): UInt {
        return resultVal
    }
}