package benchmarks

import Benchmark

class Mandelbrot : Benchmark() {
    private var n: Int = 0
    private lateinit var output: ByteArray
    
    companion object {
        private const val ITER = 50
        private const val LIMIT = 2.0
    }
    
    init {
        n = iterations
    }
    
    override fun prepare() {
        val w = n
        val h = n
        val header = "P4\n$w $h\n"
        
        val dataSize = ((w + 7) / 8) * h
        output = ByteArray(header.length + dataSize)
        header.toByteArray().copyInto(output)
    }
    
    override fun run() {
        val w = n
        val h = n
        
        var bitNum = 0
        var byteAcc = 0
        var outputIndex = "P4\n$w $h\n".length
        
        for (y in 0 until h) {
            for (x in 0 until w) {
                var zr = 0.0
                var zi = 0.0
                var tr = 0.0
                var ti = 0.0
                val cr = 2.0 * x / w.toDouble() - 1.5
                val ci = 2.0 * y / h.toDouble() - 1.0
                
                var i = 0
                while (i < ITER && tr + ti <= LIMIT * LIMIT) {
                    zi = 2.0 * zr * zi + ci
                    zr = tr - ti + cr
                    tr = zr * zr
                    ti = zi * zi
                    i += 1
                }
                
                byteAcc = byteAcc shl 1
                if (tr + ti <= LIMIT * LIMIT) {
                    byteAcc = byteAcc or 0x01
                }
                bitNum += 1
                
                if (bitNum == 8) {
                    output[outputIndex++] = byteAcc.toByte()
                    byteAcc = 0
                    bitNum = 0
                } else if (x == w - 1) {
                    if (bitNum > 0) {
                        byteAcc = byteAcc shl (8 - bitNum)
                        output[outputIndex++] = byteAcc.toByte()
                    }
                    byteAcc = 0
                    bitNum = 0
                }
            }
        }
    }
    
    override val result: Long
        get() = Helper.checksum(output).toLong()
}